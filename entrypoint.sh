#!/bin/bash

NAMENODE_DIR="/home/hdoop/dfsdata/namenode" # Adjust this path as per your Hadoop configuration

if [ ! -d "$namenode_dir/current" ]; then
  echo "formatting namenode..."
  hdfs namenode -format -force
fi

sudo service ssh start
echo "Starting NameNode..."
start-all.sh
echo "creating hive folders within hdfs..."
hdfs dfs -mkdir /tmp
hdfs dfs -chmod 777 /tmp
hdfs dfs -mkdir /user
hdfs dfs -mkdir /user/hive
hdfs dfs -mkdir /user/hive/warehouse
hdfs dfs -chmod 777 /user/hive/warehouse

echo "starting spark..."
start-master.sh
start-worker.sh spark://localhost:7077

echo "starting hive server..."
cd $HIVE_HOME
bin/hiveserver2

# echo "ready to use"
# tail -f /dev/null