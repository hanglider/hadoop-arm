#!/bin/bash
set -e

echo "=== Heavy Hadoop test (~1GB random data) ==="

# Генерация данных (~100 файлов по 10 МБ)
mkdir -p /tmp/heavy_data
for i in $(seq 1 100); do
  base64 /dev/urandom | head -c 10485760 > /tmp/heavy_data/file_$i.txt
done

# Загрузка в HDFS
hdfs dfs -rm -r -f /input_heavy >/dev/null 2>&1 || true
hdfs dfs -rm -r -f /output_heavy >/dev/null 2>&1 || true
hdfs dfs -mkdir -p /input_heavy
hdfs dfs -put /tmp/heavy_data/* /input_heavy/

# Запуск WordCount
yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount /input_heavy /output_heavy

# Вывод результата
hdfs dfs -cat /output_heavy/part-r-00000 2>/dev/null | head -n 100
