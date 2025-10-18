#!/bin/bash
set -e

echo "=== Super Heavy Hadoop test (~30GB random data) ==="
echo "⚠️ This will take a while and use significant disk space."

# Генерация данных (~300 файлов по 100 МБ)
mkdir -p /tmp/super_heavy_data
for i in $(seq 1 300); do
  base64 /dev/urandom | head -c 104857600 > /tmp/super_heavy_data/file_$i.txt
done

# Загрузка в HDFS
hdfs dfs -rm -r -f /input_super >/dev/null 2>&1 || true
hdfs dfs -rm -r -f /output_super >/dev/null 2>&1 || true
hdfs dfs -mkdir -p /input_super
hdfs dfs -put /tmp/super_heavy_data/* /input_super/

# Запуск WordCount
yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount /input_super /output_super

# Вывод результата
hdfs dfs -cat /output_super/part-r-00000 | head -n 50
