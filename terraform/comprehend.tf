#region Lambda (Input S3 => Comprehend)
resource "aws_lambda_function" "process_comprehend" {
  filename         = "./handlers/process_comprehend.zip"
  function_name    = "process_comprehend_function"
  role             = aws_iam_role.comprehend_role.arn
  handler          = "process_comprehend.lambda_handler"

  runtime          = "python3.12"
  timeout = 30
  source_code_hash = filebase64sha256("./handlers/process_comprehend.zip")

  environment {
    variables = {
        INPUT_BUCKET = aws_s3_bucket.transcribe_output_bucket.bucket
        OUTPUT_BUCKET = aws_s3_bucket.output_bucket.bucket
    }
  }
}

resource "aws_s3_bucket_notification" "transcribe_output_bucket_notification" {
  bucket = aws_s3_bucket.transcribe_output_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_comprehend.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json" #trigger for .mp4 files
  }

  depends_on = [aws_lambda_permission.comprehend_permission]
}

resource "aws_lambda_permission" "comprehend_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_comprehend.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.transcribe_output_bucket.arn
}

resource "aws_iam_role" "comprehend_role" {
  name = "comprehend-iam-role"

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

resource "aws_iam_policy" "comprehend_policy" {
  name        = "comprehend-iam-policy"
  description = "Policy for AWS Comprehend to access S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
        Resource = [
            aws_s3_bucket.transcribe_output_bucket.arn,
            "${aws_s3_bucket.transcribe_output_bucket.arn}/*",
            aws_s3_bucket.output_bucket.arn,
            "${aws_s3_bucket.output_bucket.arn}/*",
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

resource "aws_iam_role_policy_attachment" "comprehend_role_policy_attachment" {
  role       = "${aws_iam_role.comprehend_role.name}"
  policy_arn = "${aws_iam_policy.comprehend_policy.arn}"
}
#endregion