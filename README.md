# AWS Glue + Athena Experiment

Simple experiment to understand how AWS Glue and Athena work together for data processing and querying.

## What It Does

Converts CSV files to Parquet format using AWS Glue, then makes them queryable via Athena.

## Architecture

- **S3 Bucket**: Stores raw CSV files, processed Parquet files, and error records
- **Glue Job**: Reads CSV from `raw/`, validates data, converts to Parquet, writes to `processed/`
- **Glue Catalog**: Metadata database and table definition for Athena queries
- **Athena**: Query the processed Parquet data using SQL

## Data Pipeline

1. Upload CSV files to `s3://bucket/raw/`
2. Glue job processes the data:
   - Casts data types (order_id, price, quantity, timestamp)
   - Filters invalid records → `errors/`
   - Calculates revenue (price × quantity)
   - Partitions by order_date
   - Writes Parquet to `processed/`
3. Query with Athena using the `sales_db.processed_sales` table
