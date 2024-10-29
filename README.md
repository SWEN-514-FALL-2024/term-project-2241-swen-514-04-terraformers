# Vidinsight

## Setup Instructions

### For Use in EC2 or AMI (For Professors)
*To be determined.*

### For Installation on Your Local Machine (For Teammates)

#### Prerequisites
Before getting started, make sure you have the following installed on your machine:
- **Node.js** with **npm** 
- **Terraform**
- **AWS CLI**

#### Steps

1. **Install Node Packages**  
   In the root folder, run the following command to install the required npm packages:
   ```bash
   npm install
   ```

2. **Initialize Terraform**  
   Navigate to each subfolder inside the `terraform/` directory and initialize Terraform by running:
   ```bash
   terraform init
   ```

3. **Configure AWS CLI**  
   Ensure your AWS CLI is configured with your access keys:
   ```bash
   aws configure
   ```

4. **Running Terraform**  
   To apply the Terraform configurations, go to each subfolder within the `terraform/` directory and execute:
   ```bash
   terraform plan
   terraform apply
   ```

5. **Tearing Down Terraform Resources**  
   When you're finished and want to clean up the resources, run the following command in each subfolder of `terraform/`:
   ```bash
   terraform destroy
   ```

#### Automation Scripts
I’m working on automating these Terraform commands for easier use. Currently, I've created `.sh` scripts that automate the `apply`, and `destroy` commands, but these only work on UNIX-based systems. I will soon provide equivalent scripts for Windows users.
