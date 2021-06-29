SPARK_HOME=/opt/spark/spark-3.0.2-bin-hadoop3.2
PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
SPARK_RAPIDS_DIR=/opt/sparkRapidsPlugin

export PYTHONPATH=/usr/bin/python3:$PYTHONPATH
export PYSPARK_PYTHON=python3.6

# Create log files for each query that is run
LOG_SECOND=`date +%s`
LOGFILE="logs/$0.txt.$LOG_SECOND"
mkdir -p logs

# This is the IP address of the master node for your spark cluster
MASTER="spark://<SPARK_MASTER_IP>:7077"
HDFS_MASTER="<HDFS_MASTER_IP>"
#
# This is used to define the size of the dataset that is generated
# 10000 will generate a dataset of roughly 25GB in size
SCALE=10000

# Set this value to the total number of cores that you have across all
# your worker nodes. e.g. 8 servers with 40 cores = 320 cores
# NOTE: The number or executors (GPUs) needs to divide equally into the number
# of cores. Reduce the core count until you get a round number.
# In this example the servers have 320 cores, but that is not a round number
# so we will reduce this to 240. This matters because we have to slice up
# the GPU resources to be equal to the number of cores
TOTAL_CORES=1024
#
# Set this value to 1/4 the number of cores listed above. Generally,
# we have found that 4 cores per executor performs well.
NUM_EXECUTORS=256   # 1/4 the number of cores in the cluster
#
NUM_EXECUTOR_CORES=$((${TOTAL_CORES}/${NUM_EXECUTORS}))
#
# Set this to the total memory across all your worker nodes. e.g. 8 server
# with 96GB of ram = 768
TOTAL_MEMORY=3500   # unit: GB 
DRIVER_MEMORY=40    # unit: GB
#
# This takes the total memory and calculates the maximum amount of memory
# per executor
EXECUTOR_MEMORY=$(($((${TOTAL_MEMORY}-$((${DRIVER_MEMORY}*1000/1024))))/${NUM_EXECUTORS}))

# If you are going to use storage that supports S3, set your credential
# here for use during the run
# NOTE: You will need to download additonal jar files and place them in
# $SPARK_HOME/jars. The following link has instructions
# https://github.com/NVIDIA/spark-xgboost-examples/blob/spark-3/getting-started-guides/csp/aws/ec2.md#step-3-download-jars-for-s3a-optional
#
#S3A_CREDS_USR=<S3_USERNAME>
#S3A_CREDS_PSW=<S3_PASS>
#S3_ENDPOINT="https://<S3_URL>

# These paths need to be set based on what storage medium you are using
#
# For local disk use file:/// - Note that every node in your cluster must have 
# a copy of the local data on it. You can use shared storage as well, but the
# path must be consistent on all nodes
#
# For S3 storageuse s3a://
#
# **** NOTE TRAILING SLASH IS REQUIRED FOR ALL PREFIXES
#
# Input file should be set to the location of the 
# WA_Fn-UseC_-Telco-Customer-Churn-.csv file. This is used to
# generate the dataset to be used during the ETL/Analytics runs
#
# INPUT_FILE="s3a://churn-benchmark/WA_Fn-UseC_-Telco-Customer-Churn-.csv"
INPUT_FILE="hdfs://$HDFS_MASTER:9000/data/churn-benchmark/WA_Fn-UseC_-Telco-Customer-Churn-.csv"
# INPUT_FILE="file:///data/churn-benchmark/WA_Fn-UseC_-Telco-Customer-Churn-.csv"
# *****************************************************************
# Output prefix is where the data that is generated will be stored.
# This path is important as it is used for the INPUT_PREFIX for 
# the cpu and gpu env files
# *****************************************************************
#
# OUTPUT_PREFIX="s3a://data/churn-benchmark/10k/"
OUTPUT_PREFIX="hdfs://$HDFS_MASTER:9000/data/churn-benchmark/10k/"
# OUTPUT_PREFIX="file:///data/churn-benchmark/10k/"
##

S3PARAMS="--conf spark.hadoop.fs.s3a.access.key=$S3A_CREDS_USR \
  --conf spark.hadoop.fs.s3a.secret.key=$S3A_CREDS_PSW \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --conf spark.hadoop.fs.s3a.endpoint=$S3_ENDPOINT \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.experimental.input.fadvise=sequential \
  --conf spark.hadoop.fs.s3a.connection.maximum=1000\
  --conf spark.hadoop.fs.s3a.threads.core=1000\
  --conf spark.hadoop.parquet.enable.summary-metadata=false \
  --conf spark.sql.parquet.mergeSchema=false \
  --conf spark.sql.parquet.filterPushdown=true \
  --conf spark.sql.hive.metastorePartitionPruning=true \
  --conf spark.hadoop.fs.s3a.connection.ssl.enabled=true"

