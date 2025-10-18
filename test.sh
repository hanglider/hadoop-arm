#!/bin/bash
set -e
printf "Hello Hadoop\nHello World\nHadoop World\n" > /tmp/test.txt
hdfs dfs -mkdir -p /input_small
hdfs dfs -put -f /tmp/test.txt /input_small/
hdfs dfs -rm -r -f /output_small >/dev/null 2>&1 || true
yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar wordcount /input_small /output_small >/dev/null 2>&1
hdfs dfs -cat /output_small/part-r-00000 | head -n 100
