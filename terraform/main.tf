provider "aws" {
  region = "us-east-1"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

#region React EC2 Site
resource "aws_iam_role" "react_ec2_role" {
  name = "vidinsight-react-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "react_ec2_policy" {
  name = "vidinsight-react-ec2-policy"
  role = aws_iam_role.react_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::vidinsight-frontend-s3/",
          "arn:aws:s3:::vidinsight-frontend-s3/frontend/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "react_ec2_profile" {
  name = "vidinsight-react-ec2-profile"
  role = aws_iam_role.react_ec2_role.name
}

resource "aws_security_group" "react_sg" {
  name        = "vidinsight-react-sg"
  description = "Security group for frontend server"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "react_ec2" {
  depends_on    = [aws_api_gateway_deployment.deployment]
  ami           = data.aws_ami.amazonlinux.id
  instance_type = "t2.micro"
  key_name      = var.aws_key

  iam_instance_profile = aws_iam_instance_profile.react_ec2_profile.name
  security_groups      = [aws_security_group.react_sg.name]

  user_data = <<-EOF
    #!/bin/bash -x
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    nvm install node

    aws s3 cp s3://vidinsight-frontend-s3/frontend/ /home/ec2-user/frontend/ --recursive --no-sign-request
    cd /home/ec2-user/frontend/

    npm install

    echo VITE_API_GATEWAY_URL=${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_stage.prod.stage_name} >> ./.env

    npm run build

    sudo yum install nginx -y

    sudo tee /etc/nginx/conf.d/default.conf << EOL
    server {
        listen 80;
        server_name _;  # Accepts any domain name

        root /home/ec2-user/frontend/dist;  # Path to your built files
        index index.html;

        # Handle React Router
        location / {
            try_files \$uri \$uri/ /index.html =404;
        }
    }
    EOL

    sudo chmod 755 /home/ec2-user/

    echo 'Start the server'
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo systemctl reload nginx
  EOF

  tags = {
    Name = "vidinsight-react-ec2"
  }
}
#endregion

#region API Gateway
resource "aws_api_gateway_rest_api" "rest_api" {
  name        = "terraformers-vidinsight-rest-api"
  description = "REST API for Vidinsight"


  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

#region API Gateway - /url
resource "aws_api_gateway_resource" "url_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "url"
}

#region /url - POST method
resource "aws_api_gateway_method" "url_method" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.url_resource.id
  request_models = {
    "application/json" = "Empty"
  }
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "url_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.url_resource.id
  http_method             = aws_api_gateway_method.url_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.get_presigned_url.invoke_arn
}

resource "aws_api_gateway_integration_response" "url_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.url_resource.id
  http_method = aws_api_gateway_method.url_method.http_method
  status_code = aws_api_gateway_method_response.url_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.url_integration]
}

resource "aws_api_gateway_method_response" "url_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.url_resource.id
  http_method = aws_api_gateway_method.url_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [aws_api_gateway_method.url_method]
}
#endregion

#region /url - OPTIONS method
resource "aws_api_gateway_method" "url_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.url_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "url_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.url_resource.id
  http_method = aws_api_gateway_method.url_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  depends_on = [aws_api_gateway_method.url_options_method]
}

resource "aws_api_gateway_integration_response" "url_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.url_resource.id
  http_method = aws_api_gateway_method.url_options_method.http_method
  status_code = aws_api_gateway_method_response.url_options_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.url_options_method_response]
}

resource "aws_api_gateway_method_response" "url_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.url_resource.id
  http_method = aws_api_gateway_method.url_options_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  depends_on = [aws_api_gateway_method.url_options_method]
}
#endregion

#endregion


#region API Gateway - /results
resource "aws_api_gateway_resource" "results_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "results"
}

resource "aws_api_gateway_resource" "name_parameter" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_resource.results_resource.id
  path_part   = "{name}"
}

#region /results/{name} - POST method
resource "aws_api_gateway_method" "name_method" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.name_parameter.id

  request_parameters = {
    "method.request.path.name" = true
  }

  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "name_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.name_parameter.id
  http_method             = aws_api_gateway_method.name_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.get_output.invoke_arn

  # Pass the path parameter to Lambda
  request_parameters = {
    "integration.request.path.name" = "method.request.path.name"
  }
}

resource "aws_api_gateway_integration_response" "name_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.name_parameter.id
  http_method = aws_api_gateway_method.name_method.http_method
  status_code = aws_api_gateway_method_response.name_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.name_integration]
}

resource "aws_api_gateway_method_response" "name_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.name_parameter.id
  http_method = aws_api_gateway_method.name_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [aws_api_gateway_method.name_method]
}
#endregion

#region /results/{name} - OPTIONS method
resource "aws_api_gateway_method" "name_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.name_parameter.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "name_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.name_parameter.id
  http_method = aws_api_gateway_method.name_options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  depends_on = [aws_api_gateway_method.name_options_method]
}

resource "aws_api_gateway_integration_response" "name_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.name_parameter.id
  http_method = aws_api_gateway_method.name_options_method.http_method
  status_code = aws_api_gateway_method_response.name_options_method_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.name_options_method_response]
}

resource "aws_api_gateway_method_response" "name_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.name_parameter.id
  http_method = aws_api_gateway_method.name_options_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  depends_on = [aws_api_gateway_method.name_options_method]
}
#endregion

#endregion


resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration_response.url_integration_response,
    aws_api_gateway_integration_response.url_options_integration_response,
    aws_api_gateway_integration_response.name_integration_response,
    aws_api_gateway_integration_response.name_options_integration_response
  ]
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name   = "prod"
}
#endregion

#region Lambda (API Gateway => Input S3)
resource "aws_lambda_function" "get_presigned_url" {
  filename      = "./handlers/get_presigned_url.zip"
  function_name = "get_presigned_url"
  role          = aws_iam_role.input_bucket_role.arn
  handler       = "get_presigned_url.lambda_handler"

  source_code_hash = filebase64sha256("./handlers/get_presigned_url.zip")
  timeout          = 30
  runtime = "python3.12"

  environment {
    variables = {
      INPUT_BUCKET  = aws_s3_bucket.input_bucket.bucket
      OUTPUT_BUCKET = aws_s3_bucket.output_bucket.bucket
    }
  }
}

resource "aws_lambda_permission" "input_s3_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

resource "aws_iam_role" "input_bucket_role" {
  name = "input-s3-iam-role"

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

resource "aws_iam_policy" "input_s3_policy" {
  name        = "input-s3-iam-policy"
  description = "Policy to give Lambda Full Input S3 Access."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "s3:*"
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.input_bucket.arn,
          "${aws_s3_bucket.input_bucket.arn}/*"
        ]
      },
      {
        Action = "s3:*"
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.output_bucket.arn,
          "${aws_s3_bucket.output_bucket.arn}/*"
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

resource "aws_iam_role_policy_attachment" "input_s3_role_policy_attachment" {
  role       = aws_iam_role.input_bucket_role.name
  policy_arn = aws_iam_policy.input_s3_policy.arn
}
#endregion

#region Input S3
resource "aws_s3_bucket" "input_bucket" {
  bucket        = "terraformers-vidinsight-s3-input-${random_string.bucket_suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_cors_configuration" "input_bucket_cors_configuration" {
  bucket = aws_s3_bucket.input_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST", "GET", "PUT", "DELETE"]
    allowed_origins = ["*"]
  }
}
#endregion

#region Lambda (Output S3 => API Gateway)
resource "aws_lambda_function" "get_output" {
  filename      = "./handlers/get_output.zip"
  function_name = "get_output"
  role          = aws_iam_role.comprehend_role.arn
  handler       = "get_output.lambda_handler"

  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = filebase64sha256("./handlers/get_output.zip")

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.output_bucket.bucket
    }
  }
}

resource "aws_lambda_permission" "output_s3_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_output.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}

resource "aws_iam_role" "output_bucket_role" {
  name = "output-s3-iam-role"

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

resource "aws_iam_policy" "output_s3_policy" {
  name        = "output-s3-iam-policy"
  description = "Policy to give Lambda Full Output S3 Access."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "s3:*"
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.output_bucket.arn,
          "${aws_s3_bucket.output_bucket.arn}/*"
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

resource "aws_iam_role_policy_attachment" "output_s3_role_policy_attachment" {
  role       = aws_iam_role.output_bucket_role.name
  policy_arn = aws_iam_policy.output_s3_policy.arn
}
#endregion

#region Output S3
resource "aws_s3_bucket" "output_bucket" {
  bucket        = "terraformers-vidinsight-s3-output-${random_string.bucket_suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_cors_configuration" "output_bucket_cors_configuration" {
  bucket = aws_s3_bucket.output_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST", "GET", "PUT", "DELETE"]
    allowed_origins = ["*"]
  }
}
#endregion