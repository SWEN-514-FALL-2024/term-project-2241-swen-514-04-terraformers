cd api-gateway/

terraform plan && terraform apply -auto-approve

cd ../s3-react-app/

terraform plan && terraform apply -auto-approve