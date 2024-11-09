provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for storing video files to be transcribed
resource "aws_s3_bucket" "transcribe_bucket" {
  bucket = "terraformers-vidinsight-transcription-input-bucket"
  force_destroy = true
}

# S3 Bucket for storing video files after transcription
resource "aws_s3_bucket" "transcribe_output_bucket" {
  bucket = "terraformers-vidinsight-transcription-output-bucket"
  force_destroy = true
}

resource "aws_s3_bucket" "comprehend_output_bucket" {
  bucket = "terraformers-vidinsight-comprehend-output-bucket"
  force_destroy = true
}

# Public access block for the Transcribe bucket
resource "aws_s3_bucket_public_access_block" "transcribe_bucket_public_access_block" {
  bucket = aws_s3_bucket.transcribe_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "output_bucket_public_access_block" {
  bucket = aws_s3_bucket.transcribe_output_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "comprehend_output_bucket_public_access_block" {
  bucket = aws_s3_bucket.comprehend_output_bucket.id

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

resource "aws_s3_bucket_notification" "transcribe_output_bucket_notification" {
  bucket = aws_s3_bucket.transcribe_output_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.comprehend_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json" #trigger for .mp4 files
  }

  depends_on = [aws_lambda_permission.transcribe_output_allow_s3_invoke]
}

resource "aws_s3_bucket_policy" "transcribe_bucket_policy" {
  bucket = aws_s3_bucket.transcribe_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["s3:GetObject", "s3:PutObject"],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.transcribe_bucket.arn}/*",
        Principal = {
          AWS = "${aws_iam_role.transcribe_role.arn}"
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "transcribe_output_bucket_policy" {
  bucket = aws_s3_bucket.transcribe_output_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["s3:GetObject", "s3:PutObject"],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.transcribe_output_bucket.arn}/*",
        Principal = {
          AWS = "${aws_iam_role.transcribe_role.arn}"
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "comprehend_output_bucket_policy" {
  bucket = aws_s3_bucket.comprehend_output_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["s3:GetObject", "s3:PutObject"],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.comprehend_output_bucket.arn}/*",
        Principal = {
          AWS = "${aws_iam_role.transcribe_role.arn}"
        }
      }
    ]
  })
}

# IAM Role for AWS Transcribe
resource "aws_iam_role" "transcribe_role" {
  name = "terraformers-vidinsight-transcribe-role"

  # assume_role_policy = data.aws_iam_policy_document.transcribe_policy_document.json
  assume_role_policy = jsonencode({
    Version: "2012-10-17"
    Statement: [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Sid: ""
      }
    ]
  })
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
          "comprehend:DetectSentiment"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.transcribe_bucket.arn}/*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.transcribe_output_bucket.arn}/*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.comprehend_output_bucket.arn}/*"
      },
      {
            Effect = "Allow",
            Action = [
                "logs:PutLogEvents",
                "logs:CreateLogGroup",
                "logs:CreateLogStream"
            ],
            Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach the IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "transcribe_role_policy_attachment" {
  role       = "${aws_iam_role.transcribe_role.name}"
  policy_arn = "${aws_iam_policy.transcribe_policy.arn}"
}

data "archive_file" "transcribe_lambda_file" {
  # depends_on = [ null_resource.create_zip ]
  type        = "zip"
  source_file = "transcribe_lambda.py"
  output_path = "transcribe_lambda.zip"
}

data "archive_file" "comprehend_lambda_file" {
  # depends_on = [ null_resource.create_zip ]
  type        = "zip"
  source_file = "comprehend_lambda.py"
  output_path = "comprehend_lambda.zip"
}

resource "aws_lambda_function" "transcribe_lambda" {
  # depends_on = [null_resource.create_zip]
  filename         = "transcribe_lambda.zip"
  function_name    = "transcribe_lambda_function"
  role             = aws_iam_role.transcribe_role.arn
  handler          = "transcribe_lambda.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("transcribe_lambda.zip")

  environment {
    variables = {
        INPUT_BUCKET = aws_s3_bucket.transcribe_bucket.bucket
        OUTPUT_BUCKET = aws_s3_bucket.transcribe_output_bucket.bucket
    }
  }
}

resource "aws_lambda_function" "comprehend_lambda" {
  # depends_on = [null_resource.create_zip]
  filename         = "comprehend_lambda.zip"
  function_name    = "comprehend_lambda_function"
  role             = aws_iam_role.transcribe_role.arn
  handler          = "comprehend_lambda.lambda_handler"
  runtime          = "python3.9"
  timeout = 30
  source_code_hash = filebase64sha256("comprehend_lambda.zip")

  environment {
    variables = {
        INPUT_BUCKET = aws_s3_bucket.transcribe_output_bucket.bucket
        OUTPUT_BUCKET = aws_s3_bucket.comprehend_output_bucket.bucket
    }
  }
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcribe_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.transcribe_bucket.arn
}

resource "aws_lambda_permission" "transcribe_output_allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.comprehend_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.transcribe_output_bucket.arn
}