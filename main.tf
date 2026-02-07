# Create S3 bucket for data storage
resource "aws_s3_bucket" "data_bucket" {
  bucket = var.data_bucket_name
}

resource "aws_s3_object" "raw_folder" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "raw/"
}

resource "aws_s3_object" "processed_folder" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "processed/"
}

resource "aws_s3_object" "errors_folder" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "errors/"
}

resource "aws_s3_object" "scripts_folder" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "scripts/"
}

resource "aws_s3_object" "spark_history_logs_folder" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = "sparkHistoryLogs/"
}

# Upload Glue script automatically
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.data_bucket.id
  key    = var.glue_script_path
  source = "${path.module}/${var.glue_script_path}"

  etag = filemd5("${path.module}/${var.glue_script_path}")
}

# IAM Role for Glue Job
resource "aws_iam_role" "glue_role" {
  name = var.glue_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })
}

# S3 Full Access
resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Glue Console Full Access
resource "aws_iam_role_policy_attachment" "glue_full" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess"
}

resource "aws_glue_job" "csv_to_parquet" {
  name     = var.glue_job_name
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.data_bucket.bucket}/${var.glue_script_path}"
  }

  default_arguments = {
    "--enable-metrics"                = "true"
    "--spark-event-logs-path"         = "s3://${aws_s3_bucket.data_bucket.bucket}/sparkHistoryLogs/"
    "--enable-job-insights"           = "true"
    "--enable-observability-metrics"  = "true"
    "--enable-glue-datacatalog"       = "true"
    "--job-language"                  = "python"
    "--TempDir"                       = "s3://${aws_s3_bucket.data_bucket.bucket}/processed/temp/"
    "--job-bookmark-option"           = "job-bookmark-enable"
    "--BUCKET_NAME"                   = aws_s3_bucket.data_bucket.bucket
  }

  execution_property {
    max_concurrent_runs = 1
  }

  glue_version = "5.0"
  worker_type     = "G.1X"
  number_of_workers = 2
}

# Create Glue Catalog Database
resource "aws_glue_catalog_database" "analysis_db" {
  name = var.glue_database_name
}

# Create Glue Catalog Table for processed data
resource "aws_glue_catalog_table" "processed_table" {
  database_name = aws_glue_catalog_database.analysis_db.name
  name          = var.glue_table_name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_bucket.bucket}/processed/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }

    columns {
      name = "order_id"
      type = "int"
    }

    columns {
      name = "product"
      type = "string"
    }

    columns {
      name = "price"
      type = "double"
    }

    columns {
      name = "quantity"
      type = "int"
    }

    columns {
      name = "revenue"
      type = "double"
    }

    columns {
      name = "country"
      type = "string"
    }
  }

  partition_keys {
    name = "order_date"
    type = "date"
  }
}
