# Katalon ECS Terraform - Configuration Examples

## Example 1: Create New Jenkins from AMI (Recommended)

Use this when you want to create a fresh Jenkins instance from your client's AMI.

```hcl
# terraform.tfvars

# AWS Configuration
aws_region     = "us-east-1"
aws_account_id = "318798562215"

# Project Configuration
project_name = "katalon-testing"
environment  = "dev"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Jenkins - CREATE NEW FROM AMI
create_jenkins_server = true
jenkins_ami_id        = "ami-0a0403dde084aadfc"
jenkins_instance_type = "t3.medium"
jenkins_key_name      = "my-keypair"  # YOUR SSH KEY NAME

# Security - UPDATE WITH YOUR IP!
jenkins_ssh_allowed_cidrs = ["YOUR.IP.ADDRESS.HERE/32"]
jenkins_web_allowed_cidrs = ["YOUR.IP.ADDRESS.HERE/32"]

# Storage
jenkins_root_volume_size    = 50
jenkins_allocate_elastic_ip = true

# Katalon Configuration
katalon_image         = "katalonstudio/katalon:latest"
katalon_cpu           = 2048
katalon_memory        = 4096
katalon_desired_count = 0
```

After deployment:
```bash
# Get Jenkins access information
terraform output jenkins_url          # http://54.123.45.67:8080
terraform output jenkins_ssh_command  # ssh -i my-keypair.pem ec2-user@54.123.45.67
terraform output jenkins_private_ip   # 10.0.1.50
```

---

## Example 2: Use Existing Jenkins Server

Use this when you already have a running Jenkins EC2 instance.

```hcl
# terraform.tfvars

# AWS Configuration
aws_region     = "us-east-1"
aws_account_id = "318798562215"

# Project Configuration
project_name = "katalon-testing"
environment  = "dev"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Jenkins - USE EXISTING
create_jenkins_server = false
jenkins_server_ip     = "10.0.5.100/32"  # YOUR EXISTING JENKINS PRIVATE IP

# Katalon Configuration
katalon_image         = "katalonstudio/katalon:latest"
katalon_cpu           = 2048
katalon_memory        = 4096
katalon_desired_count = 0
```

After deployment:
```bash
# Attach IAM role to existing Jenkins instance
aws ec2 associate-iam-instance-profile \
  --instance-id i-xxxxxxxxxxxxx \
  --iam-instance-profile Name=$(terraform output -raw jenkins_instance_profile_name)
```

---

## Example 3: Production Configuration (New Jenkins)

Production-ready configuration with enhanced security and monitoring.

```hcl
# terraform.tfvars

# AWS Configuration
aws_region     = "us-east-1"
aws_account_id = "318798562215"

# Project Configuration
project_name = "katalon-testing"
environment  = "prod"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Jenkins - CREATE NEW FROM AMI
create_jenkins_server = true
jenkins_ami_id        = "ami-0a0403dde084aadfc"
jenkins_instance_type = "t3.large"
jenkins_key_name      = "prod-keypair"

# Security - Restricted to office/VPN IPs only
jenkins_ssh_allowed_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
jenkins_web_allowed_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]

# Storage - Separate data volume for production
jenkins_root_volume_size   = 100
jenkins_create_data_volume = true
jenkins_data_volume_size   = 500

# Features - Enhanced monitoring
jenkins_allocate_elastic_ip      = true
jenkins_enable_cloudwatch_logs   = true
jenkins_enable_cloudwatch_alarms = true

# Katalon Configuration
katalon_image         = "katalonstudio/katalon:latest"
katalon_cpu           = 4096
katalon_memory        = 8192
katalon_desired_count = 0
```

---

## Key Differences

### New Jenkins (Option 1)
- ✅ **Clean deployment** from AMI
- ✅ **Automatic configuration** via user data
- ✅ **Elastic IP** for stable access
- ✅ **Integrated monitoring**
- ❌ Requires SSH key pair
- ❌ Requires configuring security groups

**Use when:** Starting fresh or want full Terraform management

### Existing Jenkins (Option 2)
- ✅ **Keep current setup**
- ✅ **No downtime**
- ✅ **Preserve history**
- ❌ Manual IAM role attachment
- ❌ Manual configuration

**Use when:** Jenkins already running and configured

---

## Quick Start Command

```bash
# 1. Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# 2. Edit configuration
# Choose Example 1 or Example 2 above and update:
#   - jenkins_key_name (if creating new Jenkins)
#   - jenkins_ssh_allowed_cidrs
#   - jenkins_web_allowed_cidrs
nano terraform.tfvars

# 3. Deploy
terraform init
terraform plan
terraform apply

# 4. Get Jenkins info (if creating new)
terraform output jenkins_url
```

---

## Important Notes

### Security Configuration
**CRITICAL:** Never use `0.0.0.0/0` in production!

```hcl
# ❌ Bad - Open to entire internet
jenkins_ssh_allowed_cidrs = ["0.0.0.0/0"]

# ✅ Good - Restricted to your IP
jenkins_ssh_allowed_cidrs = ["203.0.113.50/32"]

# ✅ Better - Multiple known IPs
jenkins_ssh_allowed_cidrs = ["203.0.113.50/32", "198.51.100.25/32"]

# ✅ Best - Office/VPN network only
jenkins_ssh_allowed_cidrs = ["10.0.0.0/8"]
```

### Finding Your IP Address

```bash
# Your current public IP
curl https://checkip.amazonaws.com

# Use in CIDR format
jenkins_ssh_allowed_cidrs = ["$(curl -s https://checkip.amazonaws.com)/32"]
```

### SSH Key Pair

If you don't have an SSH key pair:

```bash
# Create new key pair
aws ec2 create-key-pair \
  --key-name my-keypair \
  --query 'KeyMaterial' \
  --output text > my-keypair.pem

chmod 400 my-keypair.pem

# Use the key name (without .pem)
jenkins_key_name = "my-keypair"
```

---

## What Gets Created

### With create_jenkins_server = true
- VPC with public/private subnets
- NAT Gateways
- ECS Fargate cluster
- IAM roles and policies
- Security groups
- S3 bucket for results
- **Jenkins EC2 instance**
- **Elastic IP for Jenkins**
- **CloudWatch logs and alarms**

### With create_jenkins_server = false
- VPC with public/private subnets
- NAT Gateways
- ECS Fargate cluster
- IAM roles and policies (including Jenkins role)
- Security groups
- S3 bucket for results
- *(No Jenkins instance created)*

---

## Cost Estimates

### New Jenkins (t3.medium)
- Infrastructure: ~$85/month (NAT, VPC endpoints)
- Jenkins EC2: ~$30/month
- EBS: ~$4/month
- **Total: ~$120/month**

### Existing Jenkins
- Infrastructure: ~$85/month (NAT, VPC endpoints)
- Jenkins: $0 (already paying for it)
- **Total: ~$85/month**

### ECS Usage Costs (Both Options)
- Per test run: ~$0.04/hour
- 100 tests/month @ 30min: ~$6/month

---

Choose the example that fits your use case and update the values accordingly!
