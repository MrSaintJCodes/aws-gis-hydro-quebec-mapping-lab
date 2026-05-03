data "archive_file" "opengis_app" {
  type        = "zip"
  source_dir  = "${path.module}/../app"
  output_path = "${path.module}/opengis-app.zip"
}

resource "aws_s3_bucket" "opengis_artifacts" {
  bucket_prefix = "${var.project_name}-artifacts-"

  tags = {
    Name = "${var.project_name}-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "opengis_artifacts" {
  bucket = aws_s3_bucket.opengis_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "opengis_artifacts" {
  bucket = aws_s3_bucket.opengis_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "opengis_app" {
  bucket = aws_s3_bucket.opengis_artifacts.id
  key    = "opengis/opengis-app.zip"
  source = data.archive_file.opengis_app.output_path
  etag   = data.archive_file.opengis_app.output_md5
}