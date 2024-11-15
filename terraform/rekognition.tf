# # Step 3: Create Lambda Function
# resource "aws_lambda_function" "rekognition_lambda" {
#   function_name = "S3RekognitionTrigger"
#   role          = aws_iam_role.rekognition_role.arn
#   handler       = "rek-lambda.handler"   
#   runtime       = "python3.12"       

#   filename = "./handlers/rek-lambda.zip"  
#   source_code_hash = filebase64sha256("./handlers/rek-lambda.zip")

#   environment {
#     variables = {
#       BUCKET_NAME = aws_s3_bucket.input_bucket.bucket
#       TARGET_BUCKET_NAME = aws_s3_bucket.output_bucket.bucket
#     }
#   }
# }

# resource "aws_s3_bucket_notification" "rekognition_notification" {
#   bucket = aws_s3_bucket.input_bucket.id

#   lambda_function {
#     lambda_function_arn = aws_lambda_function.rekognition_lambda.arn
#     events              = ["s3:ObjectCreated:*"]
#     filter_suffix       = ".mp4" #trigger for .mp4 files
#   }

#   depends_on = [aws_lambda_permission.rekognition_permission]
# }

# # Grant S3 permission to invoke the Lambda function
# resource "aws_lambda_permission" "rekognition_permission" {
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.rekognition_lambda.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.input_bucket.arn
# }

# # Create IAM Role for Lambda with Rekognition and S3 permissions
# resource "aws_iam_role" "rekognition_role" {
#   name = "rekognition_lambda_role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Effect = "Allow",
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_policy" "rekognition_policy" {
#   name = "RekognitionS3Policy"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = [
#           "rekognition:DetectLabels",
#           "rekognition:DetectFaces"
#         ],
#         Effect   = "Allow",
#         Resource = "*" 
#       },
#       {
#         Action = [
#           "s3:GetObject"
#         ],
#         Effect = "Allow",
#         Resource = "${aws_s3_bucket.input_bucket.arn}/*"

#       },
#       {
#         Action = [
#           "s3:PutObject"
#         ],
#         Effect = "Allow",
#         Resource = "${aws_s3_bucket.output_bucket.arn}/*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "rekognition_role_policy_attachment" {
#   role       = aws_iam_role.rekognition_role.name
#   policy_arn = aws_iam_policy.rekognition_policy.arn
# }