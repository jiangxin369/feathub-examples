#
# Copyright 2022 The Feathub Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

cd "$(dirname "$0")"
PROJECT_DIR=$(cd "$(pwd)/.."; pwd)
source "${PROJECT_DIR}"/tools/utils.sh

chmod 777 data
rm -rf data/output.json/

docker-compose up -d
wait_for_port 8020 "HDFS NameNode"
wait_for_port 50075 "HDFS DataNode"
wait_for_port 8080 "Spark Master"
wait_for_port 8081 "Spark Worker"

# HDFS may be not ready to write even if the port is serving
wait_by_command "docker exec datanode bash -c 'hadoop fs -test -e /'"

# Prepares source data files
docker exec datanode bash -c "hadoop fs -mkdir -p hdfs://namenode:8020/tmp/spark-data"
docker exec datanode bash -c "hadoop fs -put /tmp/spark-data/* hdfs://namenode:8020/tmp/spark-data/"

# Run main.py in the container and download the output from HDFS
docker exec spark-worker bash -c "python3 /tmp/main.py"
docker exec datanode bash -c "hadoop fs -get hdfs://namenode:8020/tmp/spark-data/output.json /tmp/spark-data/"

docker-compose down

cat data/output.json/* > data/merged_output

sort_and_compare_files data/merged_output data/expected_output.txt
