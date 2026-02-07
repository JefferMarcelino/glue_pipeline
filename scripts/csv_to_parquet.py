import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, to_date
from pyspark.sql.types import IntegerType, DoubleType, TimestampType

## @params: [JOB_NAME, BUCKET_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

bucket_name = args['BUCKET_NAME']
raw_path = f"s3://{bucket_name}/raw/"
processed_path = f"s3://{bucket_name}/processed/"
errors_path = f"s3://{bucket_name}/errors/"

df = spark.read.option("header", "true").csv(raw_path)

df = df.withColumn("order_id", col("order_id").cast(IntegerType())) \
       .withColumn("price", col("price").cast(DoubleType())) \
       .withColumn("quantity", col("quantity").cast(IntegerType())) \
       .withColumn("timestamp", col("timestamp").cast(TimestampType()))
       
df_valid = df.filter((col("price").isNotNull()) &
                     (col("quantity") > 0) &
                     (col("timestamp").isNotNull()))

df_invalid = df.subtract(df_valid)

df_valid = df_valid.withColumn("order_date", to_date(col("timestamp"))) \
                   .withColumn("revenue", col("price") * col("quantity"))

df_valid.write.partitionBy("order_date") \
              .mode("append") \
              .parquet(processed_path, compression="snappy")
              
df_invalid.write.mode("append").csv(errors_path, header=True)

job = Job(glueContext)
job.init(args['JOB_NAME'], args)
job.commit()
