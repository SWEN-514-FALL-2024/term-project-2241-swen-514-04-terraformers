provider "aws" {
  region = "us-east-1" 
}

# Create S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-recognition-bucket"  
  force_destroy = true               
}

# Create IAM Role for Lambda with Rekognition and S3 permissions
resource "aws_iam_role" "lambda_role" {
  name = "rekognition_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
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

resource "aws_iam_policy" "rekognition_policy" {
  name = "RekognitionS3Policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "rekognition:DetectLabels",
          "rekognition:DetectFaces"
        ],
        Effect   = "Allow",
        Resource = "*" 
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect = "Allow",
        Resource = "${aws_s3_bucket.my_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.rekognition_policy.arn
}

# Step 3: Create Lambda Function
resource "aws_lambda_function" "rekognition_lambda" {
  function_name = "S3RekognitionTrigger"
  role          = aws_iam_role.lambda_role.arn
  handler       = "rek-lambda.handler"   
  runtime       = "python3.8"       

  filename = "rek-lambda.zip"  

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.my_bucket.bucket
    }
  }
}

# Step 4: S3 Bucket Notification to Trigger Lambda
resource "aws_s3_bucket_notification" "s3_notification" {
  bucket = aws_s3_bucket.my_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.rekognition_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

# Grant S3 permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rekognition_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.my_bucket.arn
}
