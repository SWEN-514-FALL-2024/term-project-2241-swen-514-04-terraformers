provider "aws" {
  region = "us-east-1"
}

data "terraform_remote_state" "api_gateway" {
  backend = "local"
  config = {
    path = "../api-gateway/terraform.tfstate"  # Path to the state file of stage 1
  }
}

# Bucket for hosting the React App
resource "aws_s3_bucket" "react_app_bucket" {
  bucket = "terraformers-vidinsight-react-app"
}

# S3 Website Hosting Configuration
resource "aws_s3_bucket_website_configuration" "react_app_website" {
  bucket = aws_s3_bucket.react_app_bucket.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}
# Bucket Ownership Controls (Replacing ACL)
resource "aws_s3_bucket_ownership_controls" "react_app_bucket_ownership_controls" {
  bucket = aws_s3_bucket.react_app_bucket.bucket

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "react_app_public_access_block" {
  bucket = aws_s3_bucket.react_app_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public access policy for the React App bucket
resource "aws_s3_bucket_policy" "react_app_bucket_policy" {
  depends_on = [ aws_s3_bucket_public_access_block.react_app_public_access_block ]
  bucket = aws_s3_bucket.react_app_bucket.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "${aws_s3_bucket.react_app_bucket.arn}/*"
    }
  ]
}
EOF
}

# Upload React App build files to the S3 bucket from dist/ folder using aws_s3_object
resource "aws_s3_object" "react_app_files" {
  for_each = fileset("${path.module}/../../dist", "**/*")

  bucket = aws_s3_bucket.react_app_bucket.bucket
  key    = each.key
  source = "${path.module}/../../dist/${each.key}"

  # Determine content_type based on file extension
  content_type = lookup(
    {
      "html" = "text/html",
      "css"  = "text/css",
      "js"   = "application/javascript",
      "svg"  = "image/svg+xml"
    },
    regex("[^.]+$", each.key), # This extracts the file extension
    "application/octet-stream"   # Default content-type if no match
  )
}

# Output for accessing the React App via the S3 Website URL
output "react_app_url" {
  value = aws_s3_bucket_website_configuration.react_app_website.website_endpoint
  description = "URL for the React App"
}
