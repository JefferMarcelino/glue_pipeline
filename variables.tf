variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "data_bucket_name" {
  type    = string
  default = "sales-data-lake-jm"
}

variable "glue_script_path" {
  type    = string
  default = "scripts/csv_to_parquet.py"
}

variable "glue_role_name" {
  type    = string
  default = "AWSGlueRole"
}

variable "glue_job_name" {
  type    = string
  default = "csv_to_parquet_job"
}

variable "glue_database_name" {
  type    = string
  default = "sales_db"
}

variable "glue_table_name" {
  type    = string
  default = "processed_sales"
}
