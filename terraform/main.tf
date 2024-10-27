provider "aws" {
  region = "us-east-1"  
}

resource "aws_s3_bucket" "bucket" {
  bucket = "terraformers-vidinsight-s3"
}

resource "aws_s3_bucket_cors_configuration" "bucket_cors_configuration" {
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
  }
}

resource "aws_iam_role" "role" {
  name = "terraformers-vidinsight-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "policy" {
  name        = "terraformers-vidinsight-iam-policy"
  description = "Policy to give Lambda Full S3 Access."

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "s3:*"
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.bucket.arn}",
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

data "archive_file" "get_presigned_url_file" {
  type        = "zip"
  source_file = "get_presigned_url.py"
  output_path = "get_presigned_url.zip"
}

resource "aws_lambda_function" "get_presigned_url" {
  filename      = "get_presigned_url.zip"
  function_name = "get_presigned_url"
  role          = aws_iam_role.role.arn
  handler       = "get_presigned_url.lambda_handler"

  source_code_hash = data.archive_file.get_presigned_url_file.output_base64sha256

  runtime = "python3.12"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.bucket.bucket
    }
  }
}

resource "aws_api_gateway_rest_api" "rest_api" {
  name        = "terraformers-vidinsight-rest-api"
  description = "REST API for Vidinsight"
}

# Create API resource /url
resource "aws_api_gateway_resource" "url_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "url"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.url_resource.id
  request_models = {
    "application/json" = "Empty"
  }
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.url_resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_presigned_url.invoke_arn
}

resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.integration]
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name = "prod"
}

output "deployment_invoke_url" {
  description = "Deployment invoke url"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}/${aws_api_gateway_resource.url_resource.path_part}"
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
      "Resource": "${aws_s3_bucket.react_app_bucket.arn}"
    }
  ]
}
EOF
}

# Upload React App build files to the S3 bucket from dist/ folder using aws_s3_object
resource "aws_s3_object" "react_app_files" {
  for_each = fileset("${path.module}/../dist", "**/*")

  bucket = aws_s3_bucket.react_app_bucket.bucket
  key    = each.value
  source = "${path.module}/../dist/${each.value}"

  # Add content encoding if required (e.g., for gzipped assets)
  etag = filemd5("${path.module}/../dist/${each.value}")
}

# Local file for environment variable injection
resource "local_file" "env_file" {
  content  = "API_GATEWAY_URL=${aws_api_gateway_deployment.deployment.invoke_url}/${aws_api_gateway_resource.url_resource.path_part}"
  filename = "${path.module}/../dist/.env"
}

# Output for accessing the React App via the S3 Website URL
output "react_app_url" {
  value = aws_s3_bucket_website_configuration.react_app_website.website_endpoint
  description = "URL for the React App"
}
