output "deployment_invoke_url" {
  description = "Deployment invoke url"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_stage.prod.stage_name}"
}

output "react_site_url" {
  description = "React Site URL"
  value       = aws_instance.react_ec2.public_ip
}
