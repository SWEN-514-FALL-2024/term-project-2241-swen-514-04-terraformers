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

resource "null_resource" "create_zip" {
  provisioner "local-exec" {
    command = "rm get_presigned_url.zip && zip get_presigned_url.zip get_presigned_url.py"
  }
}

data "archive_file" "get_presigned_url_file" {
  depends_on = [ null_resource.create_zip ]
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

resource "aws_api_gateway_method" "options_method" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_resource.url_resource.id
    http_method   = "OPTIONS"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_resource.url_resource.id
    http_method             = aws_api_gateway_method.options_method.http_method
    type          = "MOCK"

    request_templates = {
        "application/json" = "{\"statusCode\": 200}"
    }

    depends_on = [ aws_api_gateway_method.options_method ]
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_resource.url_resource.id
    http_method             = aws_api_gateway_method.options_method.http_method
    status_code             = aws_api_gateway_method_response.options_200.status_code

    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
        "method.response.header.Access-Control-Allow-Origin" = "'*'"
    }
    depends_on = [ aws_api_gateway_method_response.options_200 ]
}

resource "aws_api_gateway_method_response" "options_200" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_resource.url_resource.id
    http_method             = aws_api_gateway_method.options_method.http_method
    status_code   = "200"

    response_models = {
        "application/json" = "Empty"
    }

    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = true,
        "method.response.header.Access-Control-Allow-Methods" = true,
        "method.response.header.Access-Control-Allow-Origin" = true
    }

    depends_on = [ aws_api_gateway_method.options_method ]
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

# Local file for environment variable injection
resource "local_file" "build" {
  content  = "VITE_API_GATEWAY_URL=${aws_api_gateway_deployment.deployment.invoke_url}/${aws_api_gateway_resource.url_resource.path_part}"
  filename = "${path.module}/../../.env"

  provisioner "local-exec" {
    command = "cd ${path.module}/../.. && npm run build"
  }
}

output "deployment_invoke_url" {
  description = "Deployment invoke url"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}/${aws_api_gateway_resource.url_resource.path_part}"
}