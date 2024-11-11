data "aws_ami" "amazonlinux" {
    most_recent = true
    owners     = ["amazon"]

    filter {
        name="name"
        values = ["al2023-ami-2023*"]
    }
    filter {
        name="virtualization-type"
        values = ["hvm"]
    }
    filter {
        name="root-device-type"
        values = ["ebs"]
    }
    filter {
        name="architecture"
        values = ["x86_64"]
    }
}

data "archive_file" "get_presigned_url_file" {
  type        = "zip"
  source_file = "./handlers/get_presigned_url.py"
  output_path = "./handlers/get_presigned_url.zip"
}

data "archive_file" "transcribe_lambda_file" {
  type        = "zip"
  source_file = "./handlers/transcribe_lambda.py"
  output_path = "./handlers/transcribe_lambda.zip"
}

data "archive_file" "comprehend_lambda_file" {
  type        = "zip"
  source_file = "./handlers/comprehend_lambda.py"
  output_path = "./handlers/comprehend_lambda.zip"
}