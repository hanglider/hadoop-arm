SHELL := /bin/bash

# всегда используем resourcemanager, без прокидываний переменных
HADOOP_CONTAINER := resourcemanager

DATA_DIR := data
EMAILS_FILE := $(DATA_DIR)/emails.txt
SPLITS_DIR := $(DATA_DIR)/splits

REPOS_FILE ?= repos.txt
MAX_COMMITS ?= 0

# сколько строк в одном куске (меньше => больше mapper-ов)
SPLIT_LINES ?= 5000

HDFS_INPUT_DIR := /input/vendors
HDFS_OUTPUT_DIR := /output/top_vendors

# фильтр мусора из логов Hadoop (stderr/stdout)
NOISE_RE := "Unable to load native-hadoop library|packageJobJar:|Connecting to ResourceManager|Disabling Erasure Coding|Submitting tokens|Executing with tokens|resource-types.xml not found|Unable to find 'resource-types.xml'|Submitted application|The url to track the job|Counters:|File System Counters|Map-Reduce Framework|Shuffle Errors|Job Counters|File Input Format Counters|File Output Format Counters|INFO client.DefaultNoHARMFailoverProxyProvider|INFO mapreduce.JobSubmitter|INFO conf.Configuration|INFO resource.ResourceUtils|INFO impl.YarnClientImpl|INFO mapred.FileInputFormat|INFO mapreduce.JobResourceUploader"

.PHONY: pipeline all prepare run show fetch clean git split hdfs-put hdfs-clean

all: pipeline
pipeline: prepare run fetch

# 1) скачать/обновить репо и собрать emails
git:
	@mkdir -p $(DATA_DIR)
	@python3 tools/extract_emails.py --repos $(REPOS_FILE) --out $(EMAILS_FILE) --max-commits $(MAX_COMMITS)

# 2) нарезать emails на много файлов
split: git
	@rm -rf $(SPLITS_DIR)
	@mkdir -p $(SPLITS_DIR)
	@if [[ "$(SPLIT_LINES)" == "0" ]]; then \
	  cp "$(EMAILS_FILE)" "$(SPLITS_DIR)/part-00000"; \
	else \
	  split -l "$(SPLIT_LINES)" -a 4 -d "$(EMAILS_FILE)" "$(SPLITS_DIR)/part-"; \
	fi
	@echo "OK: prepared splits in $(SPLITS_DIR) (SPLIT_LINES=$(SPLIT_LINES))"

# очистить input/output в HDFS (на всякий)
hdfs-clean:
	@docker exec -i $(HADOOP_CONTAINER) bash -lc 'hdfs dfs -rm -r -f "$(HDFS_INPUT_DIR)" >/dev/null 2>&1 || true; hdfs dfs -rm -r -f "$(HDFS_OUTPUT_DIR)" >/dev/null 2>&1 || true'

# 3) залить splits в HDFS: ВАЖНО — копируем содержимое, не папку, и чистим /tmp/splits
hdfs-put: split
	@docker exec -i $(HADOOP_CONTAINER) bash -lc 'rm -rf /tmp/splits && mkdir -p /tmp/splits'
	@docker cp $(SPLITS_DIR)/. $(HADOOP_CONTAINER):/tmp/splits >/dev/null
	@docker exec -i $(HADOOP_CONTAINER) bash -lc '\
	  set -euo pipefail; \
	  hdfs dfs -rm -r -f "$(HDFS_INPUT_DIR)" >/dev/null 2>&1 || true; \
	  hdfs dfs -mkdir -p "$(HDFS_INPUT_DIR)" >/dev/null 2>&1; \
	  hdfs dfs -put -f /tmp/splits/* "$(HDFS_INPUT_DIR)/" >/dev/null 2>&1; \
	'
	@echo "OK: uploaded input to HDFS: $(HDFS_INPUT_DIR)"

prepare: hdfs-put

# 4) запуск job: без мусора, и чтобы make реально падал при ошибке
run:
	@docker cp mapper.py $(HADOOP_CONTAINER):/tmp/mapper.py >/dev/null
	@docker cp reducer.py $(HADOOP_CONTAINER):/tmp/reducer.py >/dev/null
	@docker exec -i $(HADOOP_CONTAINER) bash -lc '\
	  set -euo pipefail; \
	  command -v python3 >/dev/null 2>&1 || (apt-get update >/dev/null && apt-get install -y python3 >/dev/null); \
	  JAR=$$(ls -1 /opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -n 1); \
	  hdfs dfs -rm -r -f "$(HDFS_OUTPUT_DIR)" >/dev/null 2>&1 || true; \
	  set +e; \
	  hadoop jar "$$JAR" \
	    -D mapreduce.job.reduces=1 \
	    -files /tmp/mapper.py,/tmp/reducer.py \
	    -mapper "python3 mapper.py" \
	    -reducer "python3 reducer.py" \
	    -input "$(HDFS_INPUT_DIR)" \
	    -output "$(HDFS_OUTPUT_DIR)" \
	    2>&1 | grep -vE $(NOISE_RE) | grep -E "Running job:|mapreduce.Job:  map|mapreduce.Job:  map [0-9]+% reduce [0-9]+%|completed successfully|ERROR|Exception|FAILED|Not a file" ; \
	  rc=$${PIPESTATUS[0]}; \
	  set -e; \
	  exit $$rc; \
	'
	@echo "OK: output in HDFS: $(HDFS_OUTPUT_DIR)"

# 5) чистый показ результата (без WARN/INFO)
show:
	@docker exec -i $(HADOOP_CONTAINER) bash -lc 'hdfs dfs -cat "$(HDFS_OUTPUT_DIR)"/part-* 2>/dev/null'

fetch:
	@mkdir -p $(DATA_DIR)
	@docker exec -i $(HADOOP_CONTAINER) bash -lc 'hdfs dfs -cat "$(HDFS_OUTPUT_DIR)"/part-* 2>/dev/null' > $(DATA_DIR)/result.txt
	@echo "Saved: $(DATA_DIR)/result.txt"

clean:
	@rm -rf $(DATA_DIR)