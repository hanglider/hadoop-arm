# ========= Makefile for native ARM64 Hadoop cluster =========

APP_NAME := hadoop-arm
HADOOP_TAG := 3.3.6

DOCKER := docker
COMPOSE := docker compose

.PHONY: build up ps logs test run-test down clean nuke restart

# Build local ARM64 image
build:
	$(DOCKER) buildx build --platform linux/arm64 -t $(APP_NAME):$(HADOOP_TAG) . --load

# Start cluster
up:
	$(COMPOSE) up -d

# Status helpers
ps:
	$(DOCKER) ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

logs:
	@echo "---- namenode ----"; $(DOCKER) logs --tail=60 namenode || true; \
	echo ""; echo "---- datanode ----"; $(DOCKER) logs --tail=30 datanode || true; \
	echo ""; echo "---- resourcemanager ----"; $(DOCKER) logs --tail=30 resourcemanager || true; \
	echo ""; echo "---- nodemanager ----"; $(DOCKER) logs --tail=30 nodemanager || true

# Run WordCount
test:
	$(DOCKER) exec -it resourcemanager bash -lc "bash /opt/test.sh"

# One-shot: build + up + test
run-test: build up wait test

wait:
	@echo "Waiting 15s for Hadoop services..."; sleep 15

# Stop / clean
down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v

nuke:
	$(COMPOSE) down -v || true
	$(DOCKER) system prune -af || true
	$(DOCKER) volume prune -f || true

restart: down up

heavy:
	docker exec -it resourcemanager bash -lc "bash /opt/heavy_test.sh"

super:
	docker exec -it resourcemanager bash -lc "bash /opt/super_heavy_test.sh"

alltests:
	$(MAKE) test
	$(MAKE) heavy
	$(MAKE) super
