#!/bin/bash
set -e

echo "=== Hadoop test: WordCount ==="
sleep 10  

hdfs dfs -mkdir -p /input
echo "Hello Hadoop Hello World" > /tmp/test.txt
hdfs dfs -put -f /tmp/test.txt /input

hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar wordcount /input /output

echo "=== WordCount output ==="
hdfs dfs -cat /output/part-r-00000