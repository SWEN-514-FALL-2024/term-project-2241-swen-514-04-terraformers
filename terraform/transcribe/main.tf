provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for storing video files to be transcribed
resource "aws_s3_bucket" "transcribe_bucket" {
  bucket = "terraformers-vidinsight-transcription-input-bucket"
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

# S3 bucket notification to trigger transcribe
resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket = aws_s3_bucket.transcribe_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcribe_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".mp4" #trigger for .mp4 files
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# S3 Bucket for storing video files after transcription
resource "aws_s3_bucket" "output_bucket" {
  bucket = "terraformers-vidinsight-transcription-output-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "output_bucket_public_access_block" {
  bucket = aws_s3_bucket.output_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# IAM Role for AWS Transcribe
resource "aws_iam_role" "transcribe_role" {
  name = "terraformers-vidinsight-transcribe-role"

  assume_role_policy = data.aws_iam_policy_document.transcribe_policy_document.json
  # assume_role_policy = jsonencode({
  #   Version = "2012-10-17"
  #   Statement = [
  #     {
  #       Action = "sts:AssumeRole",
  #       Effect = "Allow",
  #       Principal = {
  #         #Service = "transcribe.amazonaws.com",
  #         Service = "lambda.amazonaws.com"
  #       }
  #     }
  #   ]
  # })
}

data "aws_iam_policy_document" "transcribe_policy_document"{

  statement{
    effect = "Allow"

    principals{
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

}

# IAM Policy to allow Transcribe to access the S3 bucket
resource "aws_iam_policy" "transcribe_policy" {
  name        = "transcribe-policy"
  description = "Policy for AWS Transcribe to access S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "transcribe:StartTranscriptionJob",
          "transcribe:GetTranscriptionJob",
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject"
        ],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.transcribe_bucket.arn}/*"
      },
      {
        Action = [
          "s3:PutObject"
        ],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.output_bucket.arn}/*"
      }
    ]
  })
}

# Attach the IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "transcribe_role_policy_attachment" {
  role       = "${aws_iam_role.transcribe_role.name}"
  policy_arn = "${aws_iam_policy.transcribe_policy.arn}"
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
  # handler          = "transcribe_lambda.lambda_handler"
  handler          = "lambda_handler"
  runtime          = "python3.12"

  environment {
    variables = {
        INPUT_BUCKET = aws_s3_bucket.transcribe_bucket.bucket
        OUTPUT_BUCKET = aws_s3_bucket.output_bucket.bucket
    }
  }
  source_code_hash = data.archive_file.transcribe_lambda_file.output_base64sha256
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcribe_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.transcribe_bucket.arn
}

# output "transcribe_bucket_name"{
#   value         = aws_s3_bucket.transcribe_bucket.bucket
#   description   = "S3 bucket for storing video files for transcription"
# }

# output "output_bucket_name"{
#   value         = aws_s3_bucket.output_bucket.bucket
#   description   = "S3 bucket for storing transcription output"
# }
