provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for storing video files to be transcribed
# Should be the same as the bucket created in api-gateway?
resource "aws_s3_bucket" "transcribe_bucket" {
  bucket = "terraformers-vidinsight-transcribe-bucket"
  force_destroy = true
}

# Bucket Ownership Controls (Replacing ACL)
resource "aws_s3_bucket_ownership_controls" "transcribe_bucket_ownership_controls" {
  bucket = aws_s3_bucket.transcribe_bucket.bucket

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Public access block for the Transcribe bucket
resource "aws_s3_bucket_public_access_block" "transcribe_bucket_public_access_block" {
  bucket = aws_s3_bucket.transcribe_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# IAM Role for AWS Transcribe
resource "aws_iam_role" "transcribe_role" {
  name = "terraformers-vidinsight-transcribe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "transcribe.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy to allow Transcribe to access the S3 bucket
resource "aws_iam_policy" "transcribe_policy" {
  name        = "terraformers-vidinsight-transcribe-policy"
  description = "Policy for AWS Transcribe to access S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "transcribe:StartTranscriptionJob",
          "transcribe:GetTranscriptionJob",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.transcribe_bucket.arn}/*"
        ]
      },
      #unsure if i need this below because i put it above in actions
      # {
      #   Action = [
      #     "transcribe:StartTranscriptionJob",
      #     "transcribe:GetTranscriptionJob"
      #   ],
      #   Effect = "Allow",
      #   Resource = "*"
      # }
    ]
  })
}

# Attach the IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "transcribe_role_policy_attachment" {
  role       = aws_iam_role.transcribe_role.name
  policy_arn = aws_iam_policy.transcribe_policy.arn
}

# IAM Role for Lambda
resource "aws_iam_role" "transcribe_lambda_role" {
  name = "terraformers-vidinsight-transcribe-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy to allow Lambda to access Transcribe and S3
resource "aws_iam_policy" "transcribe_lambda_policy" {
  name        = "terraformers-vidinsight-transcribe-lambda-policy"
  description = "Policy for Lambda to access AWS Transcribe and S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "transcribe:StartTranscriptionJob",
          "transcribe:GetTranscriptionJob"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.transcribe_bucket.arn}/*"
        ]
      }
    ]
  })
}

# resource "null_resource" "create_zip" {
#   provisioner "local-exec" {
#     command = "zip transcribe_lambda.zip transcribe_lambda.py"
#   }

#   triggers = {
#     source = filemd5("transcribe_lambda.py")
#   }
# }

data "archive_file" "transcribe_lambda_file" {
  # depends_on = [ null_resource.create_zip ]
  type        = "zip"
  source_file = "transcribe_lambda.py"
  output_path = "transcribe_lambda.zip"
}

resource "aws_lambda_function" "transcribe_lambda" {
  # depends_on = [null_resource.create_zip]
  filename         = "transcribe_lambda.zip"
  function_name    = "transcribe_lambda_function"
  role             = aws_iam_role.transcribe_role.arn
  handler          = "transcribe_video.lambda_handler"
  runtime          = "python3.12"

  environment {
    variables = {
        BUCKET_NAME = aws_s3_bucket.transcribe_bucket.bucket
    }
  }
  source_code_hash = data.archive_file.transcribe_lambda_file.output_base64sha256
  # source_code_hash = filebase64sha256("transcribe_lambda.zip")
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcribe_lambda.function_name
  principal     = "s3.amazonaws.com"
}

# API Gateway to trigger the Lambda function (if needed)
resource "aws_api_gateway_rest_api" "transcribe_api" {
  name        = "TranscribeAPI"
  description = "API for triggering transcription jobs"
}

# Create API resource for transcription
resource "aws_api_gateway_resource" "transcribe_resource" {
  rest_api_id = aws_api_gateway_rest_api.transcribe_api.id
  parent_id   = aws_api_gateway_rest_api.transcribe_api.root_resource_id
  path_part   = "transcribe"
}

resource "aws_api_gateway_method" "transcribe_method" {
  rest_api_id   = aws_api_gateway_rest_api.transcribe_api.id
  resource_id   = aws_api_gateway_resource.transcribe_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "transcribe_integration" {
  rest_api_id             = aws_api_gateway_rest_api.transcribe_api.id
  resource_id             = aws_api_gateway_resource.transcribe_resource.id
  http_method             = aws_api_gateway_method.transcribe_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.transcribe_lambda.invoke_arn
}

# Output for the Transcribe bucket and API URL
output "transcribe_bucket_name" {
  value       = aws_s3_bucket.transcribe_bucket.bucket
  description = "Name of the S3 bucket for storing video files for transcription."
}

output "transcribe_api_url" {
  value       = "${aws_api_gateway_rest_api.transcribe_api.execution_arn}/${aws_api_gateway_resource.transcribe_resource.path_part}"
  description = "API URL for triggering transcription jobs."
}
