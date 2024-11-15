
#region Lambda (Input S3 => Transcribe)
resource "aws_lambda_function" "transcribe_lambda" {
  filename      = "./handlers/transcribe_lambda.zip"
  function_name = "transcribe_lambda_function"
  role          = aws_iam_role.transcribe_role.arn
  handler       = "transcribe_lambda.lambda_handler"

  runtime          = "python3.12"
  source_code_hash = filebase64sha256("./handlers/transcribe_lambda.zip")

  environment {
    variables = {
      INPUT_BUCKET  = aws_s3_bucket.input_bucket.bucket
      OUTPUT_BUCKET = aws_s3_bucket.transcribe_output_bucket.bucket
      SNS_TOPIC_ARN = aws_sns_topic.rekognition_updates.arn
      REKOGNITION_ROLE_ARN = aws_iam_role.rekognition_sns_role.arn
    }
  }
}

resource "aws_s3_bucket_notification" "input_bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.transcribe_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".mp4" #trigger for .mp4 files
  }

  depends_on = [aws_lambda_permission.transcribe_permission]
}

resource "aws_lambda_permission" "transcribe_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transcribe_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}

resource "aws_iam_role" "transcribe_role" {
  name = "transcribe-iam-role"

  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Sid : ""
      }
    ]
  })
}

resource "aws_iam_policy" "transcribe_policy" {
  name        = "transcribe-iam-policy"
  description = "Policy for AWS Transcribe to access S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "transcribe:StartTranscriptionJob",
          "rekognition:StartLabelDetection",
          "iam:PassRole"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.input_bucket.arn,
          "${aws_s3_bucket.input_bucket.arn}/*",
          aws_s3_bucket.transcribe_output_bucket.arn,
          "${aws_s3_bucket.transcribe_output_bucket.arn}/*"
        ]

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

resource "aws_iam_role_policy_attachment" "transcribe_role_policy_attachment" {
  role       = aws_iam_role.transcribe_role.name
  policy_arn = aws_iam_policy.transcribe_policy.arn
}
#endregion

#region SNS + Rekognition

# SNS
resource "aws_sns_topic" "rekognition_updates" {
  name = "video-rekognition-updates"
}

resource "aws_iam_role" "rekognition_sns_role" {
  name = "rekognition-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rekognition.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "rekognition_sns_publish_policy" {
  name        = "rekognition-sns-publish-policy"
  description = "Policy for Rekognition to publish to SNS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = aws_sns_topic.rekognition_updates.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rekognition_sns_policy_attachment" {
  role       = aws_iam_role.rekognition_sns_role.name
  policy_arn = aws_iam_policy.rekognition_sns_publish_policy.arn
}

# When completed, run this Lambda
resource "aws_sns_topic_subscription" "rekognition_updates_lambda" {
  topic_arn = aws_sns_topic.rekognition_updates.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.process_rekognition.arn

  depends_on = [ aws_lambda_permission.rekognition_sns ]
}

resource "aws_lambda_permission" "rekognition_sns" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_rekognition.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.rekognition_updates.arn
}

# Rekognition
resource "aws_lambda_function" "process_rekognition" {
  filename         = "./handlers/process_rekognition.zip"
  function_name    = "process_rekognition_results"
  role             = aws_iam_role.rekognition_processor_role.arn
  handler          = "process_rekognition.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.output_bucket.bucket
    }
  }
}

resource "aws_iam_role" "rekognition_processor_role" {
  name = "rekognition-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "rekognition_processor_policy" {
  name        = "rekognition-processor-policy"
  description = "Policy for Lambda processing Rekognition results"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:GetLabelDetection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.output_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rekognition_processor_policy_attachment" {
  role       = aws_iam_role.rekognition_processor_role.name
  policy_arn = aws_iam_policy.rekognition_processor_policy.arn
}
#endregion


#region Transcribe Output S3
resource "aws_s3_bucket" "transcribe_output_bucket" {
  bucket        = "terraformers-vidinsight-transcription-output-bucket-${random_string.bucket_suffix.result}"
  force_destroy = true
}
#endregion
