# Jenkins Module - Deployment Guide

This guide covers deploying Jenkins from your client's AMI as part of the Katalon ECS infrastructure.

## Two Deployment Options

### Option 1: Use Existing Jenkins Server

If you already have a Jenkins EC2 instance:

```hcl
# In terraform.tfvars
create_jenkins_server = false
jenkins_server_ip     = "10.0.5.100/32"  # Your existing Jenkins private IP
```

Then manually attach the IAM instance profile after deployment:

```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-xxxxxxxxxxxxx \
  --iam-instance-profile Name=$(terraform output -raw jenkins_instance_profile_name)
```

### Option 2: Create Jenkins from AMI (Recommended)

Deploy a new Jenkins instance from your client's AMI:

```hcl
# In terraform.tfvars
create_jenkins_server = true
jenkins_ami_id        = "ami-0abcdef1234567890"  # Client's Jenkins AMI
jenkins_key_name      = "my-keypair"

# Security (RESTRICT IN PRODUCTION!)
jenkins_ssh_allowed_cidrs = ["203.0.113.0/24"]  # Your office IP
jenkins_web_allowed_cidrs = ["203.0.113.0/24"]  # Your office IP
```

## Step-by-Step: Creating Jenkins from AMI

### Step 1: Prepare AMI Information

Get your client's Jenkins AMI ID:

```bash
# List AMIs in your account
aws ec2 describe-images --owners self \
  --query 'Images[*].[ImageId,Name,CreationDate]' \
  --output table

# Or search by name
aws ec2 describe-images --owners self \
  --filters "Name=name,Values=jenkins-*" \
  --query 'Images[*].[ImageId,Name]' \
  --output table
```

### Step 2: Configure terraform.tfvars

```hcl
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

# Jenkins Configuration - CREATE FROM AMI
create_jenkins_server = true

# Jenkins AMI
jenkins_ami_id = "ami-0abcdef1234567890"  # REQUIRED: Your client's AMI

# Instance Configuration
jenkins_instance_type = "t3.medium"       # Adjust based on needs
jenkins_key_name      = "my-keypair"      # REQUIRED: Your SSH key

# Security - IMPORTANT: Restrict these!
jenkins_ssh_allowed_cidrs = ["203.0.113.0/24"]  # Your office/VPN IP
jenkins_web_allowed_cidrs = ["203.0.113.0/24"]  # Your office/VPN IP

# Storage
jenkins_root_volume_size   = 50
jenkins_create_data_volume = false  # Set true for separate data volume
jenkins_data_volume_size   = 100

# Features
jenkins_allocate_elastic_ip      = true
jenkins_enable_cloudwatch_logs   = true
jenkins_enable_cloudwatch_alarms = true

# Katalon Configuration
katalon_image         = "katalonstudio/katalon:latest"
katalon_cpu           = 2048
katalon_memory        = 4096
katalon_desired_count = 0
```

### Step 3: Deploy Infrastructure

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

### Step 4: Get Jenkins Access Information

```bash
# Get Jenkins URL
terraform output jenkins_url

# Get SSH command
terraform output jenkins_ssh_command

# Get all Jenkins info
terraform output | grep jenkins
```

Example output:
```
jenkins_url = "http://54.123.45.67:8080"
jenkins_ssh_command = "ssh -i my-keypair.pem ec2-user@54.123.45.67"
```

### Step 5: Access Jenkins

```bash
# SSH to Jenkins (if needed)
ssh -i my-keypair.pem ec2-user@54.123.45.67

# Access web interface
# Open browser to: http://54.123.45.67:8080
```

### Step 6: Verify ECS Integration

The user data script automatically configures ECS integration. Verify:

```bash
# SSH into Jenkins
ssh -i my-keypair.pem ec2-user@<jenkins-ip>

# Check environment variables
cat /etc/jenkins/ecs-config.env

# Verify ECS access
aws ecs describe-clusters --clusters katalon-testing-dev-cluster

# Verify S3 access
aws s3 ls
```

## Post-Deployment Configuration

### Configure Jenkins Jobs

The Jenkins instance is pre-configured with environment variables:

- `ECS_CLUSTER_NAME` - Your ECS cluster name
- `TASK_DEFINITION_FAMILY` - Katalon task definition
- `AWS_REGION` - AWS region
- `S3_RESULTS_BUCKET` - S3 bucket for test results

Use these in your Jenkins pipelines or copy the provided `Jenkinsfile`.

### Using the Helper Script

A helper script is installed at `/usr/local/bin/run-katalon-test`:

```bash
# From Jenkins server
sudo run-katalon-test smoke-tests https://example.com
```

This script automatically:
1. Gets network configuration from ECS cluster
2. Runs ECS task with specified parameters
3. Returns task ARN for monitoring

## Security Configuration

### Restrict Access (CRITICAL!)

The example uses `0.0.0.0/0` which is **NOT SECURE**. Always restrict:

```hcl
# Good - Restricted to your office
jenkins_ssh_allowed_cidrs = ["203.0.113.0/24"]
jenkins_web_allowed_cidrs = ["203.0.113.0/24"]

# Better - Multiple specific IPs
jenkins_ssh_allowed_cidrs = ["203.0.113.10/32", "203.0.113.20/32"]
jenkins_web_allowed_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]

# Best - VPN only
jenkins_ssh_allowed_cidrs = ["10.0.0.0/8"]  # VPN range
jenkins_web_allowed_cidrs = ["10.0.0.0/8"]  # VPN range
```

### Security Group Rules Created

The module creates these rules automatically:

**Inbound:**
- Port 22 (SSH) from `jenkins_ssh_allowed_cidrs`
- Port 8080 (Jenkins) from `jenkins_web_allowed_cidrs`
- Port 443 (HTTPS) from `jenkins_web_allowed_cidrs`

**Outbound:**
- All traffic (for AWS API access, package downloads, etc.)

### Additional Security Measures

1. **Use Elastic IP** - Provides stable, manageable access
2. **Enable CloudWatch Logs** - For audit trail
3. **Set up CloudWatch Alarms** - Get notified of issues
4. **Use VPN** - Route all access through corporate VPN
5. **Enable MFA** - For Jenkins admin accounts
6. **Regular Updates** - Keep Jenkins and plugins updated

## Storage Configuration

### Default (Root Volume Only)

```hcl
jenkins_root_volume_size   = 50
jenkins_create_data_volume = false
```

All Jenkins data on root volume. Good for:
- Development/testing
- Small Jenkins installations
- When using AMI with pre-configured storage

### With Data Volume (Recommended for Production)

```hcl
jenkins_root_volume_size   = 50
jenkins_create_data_volume = true
jenkins_data_volume_size   = 200
```

Separate data volume for Jenkins. Benefits:
- Easy backups (snapshot data volume only)
- Easier migration (detach and reattach)
- Better performance (dedicated IOPS)

#### Mounting Data Volume

After instance creation, mount the data volume:

```bash
# SSH to Jenkins
ssh -i my-key.pem ec2-user@<jenkins-ip>

# Format volume (only first time!)
sudo mkfs -t ext4 /dev/sdf

# Create mount point
sudo mkdir /jenkins-data

# Mount volume
sudo mount /dev/sdf /jenkins-data

# Set ownership
sudo chown jenkins:jenkins /jenkins-data

# Add to fstab for persistence
echo '/dev/sdf /jenkins-data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Verify
df -h | grep jenkins-data
```

## Monitoring

### CloudWatch Logs

Jenkins logs are sent to CloudWatch:

```bash
# View real-time logs
aws logs tail /aws/ec2/katalon-testing-dev/jenkins --follow

# View specific log file
aws logs tail /aws/ec2/katalon-testing-dev/jenkins \
  --log-stream-name <instance-id>/jenkins.log --follow

# View user data script logs
aws logs tail /aws/ec2/katalon-testing-dev/jenkins \
  --log-stream-name <instance-id>/user-data.log
```

### CloudWatch Alarms

Two alarms are created automatically:

1. **High CPU Alarm**
   - Threshold: 80% (configurable)
   - Duration: 2 periods of 5 minutes
   
2. **Status Check Alarm**
   - Triggers on instance health check failure
   - Duration: 2 periods of 1 minute

Configure SNS topic for notifications:

```hcl
# Create SNS topic (separate resource)
resource "aws_sns_topic" "jenkins_alerts" {
  name = "jenkins-alerts"
}

resource "aws_sns_topic_subscription" "jenkins_alerts_email" {
  topic_arn = aws_sns_topic.jenkins_alerts.arn
  protocol  = "email"
  endpoint  = "ops@example.com"
}

# Use in Jenkins module
module "jenkins" {
  # ... other config ...
  alarm_sns_topic_arn = aws_sns_topic.jenkins_alerts.arn
}
```

### Instance Monitoring

```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id>

# View CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## DNS Configuration (Optional)

### Using Route53

```hcl
# In terraform.tfvars
create_dns_record = true
route53_zone_id   = "Z1234567890ABC"  # Your hosted zone ID
jenkins_hostname  = "jenkins.example.com"
```

Then access Jenkins at: `http://jenkins.example.com:8080`

### Getting Zone ID

```bash
# List hosted zones
aws route53 list-hosted-zones

# Get specific zone
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`example.com.`].Id' \
  --output text
```

## Backup Configuration (Optional)

### AWS Backup Integration

First, create a backup plan:

```hcl
# Create backup vault
resource "aws_backup_vault" "jenkins" {
  name = "jenkins-backup-vault"
}

# Create backup plan
resource "aws_backup_plan" "jenkins" {
  name = "jenkins-daily-backup"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.jenkins.name
    schedule          = "cron(0 2 * * ? *)"  # 2 AM daily

    lifecycle {
      delete_after = 30
    }
  }
}

# Create IAM role for backup
resource "aws_iam_role" "backup" {
  name = "jenkins-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
```

Then enable backup in Jenkins module:

```hcl
module "jenkins" {
  # ... other config ...
  
  enable_backup        = true
  backup_plan_id       = aws_backup_plan.jenkins.id
  backup_iam_role_arn  = aws_iam_role.backup.arn
}
```

## Troubleshooting

### Jenkins Won't Start

```bash
# Check Jenkins service status
sudo systemctl status jenkins

# View Jenkins logs
sudo tail -f /var/log/jenkins/jenkins.log

# Check user data script
sudo cat /var/log/user-data.log

# Check for errors
sudo journalctl -u jenkins -n 50
```

### Can't Access Jenkins Web Interface

```bash
# Check if Jenkins is listening
sudo netstat -tlnp | grep 8080

# Check security group
aws ec2 describe-security-groups --group-ids <sg-id>

# Test from local machine
curl -I http://<jenkins-ip>:8080
```

### ECS Integration Not Working

```bash
# Check IAM role
aws sts get-caller-identity

# Verify instance profile
aws ec2 describe-iam-instance-profile-associations \
  --filters Name=instance-id,Values=<instance-id>

# Test ECS access
aws ecs list-clusters

# Check environment variables
cat /etc/jenkins/ecs-config.env
```

### CloudWatch Logs Not Appearing

```bash
# Check agent status
sudo amazon-cloudwatch-agent-ctl -a query -m ec2 -c default -s

# Check config
cat /opt/aws/amazon-cloudwatch-agent/etc/config.json

# Restart agent
sudo systemctl restart amazon-cloudwatch-agent

# Check agent logs
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

## Cost Optimization

### Instance Sizing

Choose instance type based on workload:

| Type | vCPU | RAM | Use Case | Cost/Month |
|------|------|-----|----------|------------|
| t3.small | 2 | 2 GB | Light usage | ~$15 |
| t3.medium | 2 | 4 GB | Standard | ~$30 |
| t3.large | 2 | 8 GB | Heavy | ~$60 |
| t3.xlarge | 4 | 16 GB | Very heavy | ~$120 |

### Storage Costs

- gp3 (default): ~$0.08/GB/month
- gp2: ~$0.10/GB/month  
- io1: ~$0.125/GB/month + IOPS costs

### Data Transfer

- Data IN: Free
- Data OUT to internet: $0.09/GB (first 10TB)
- Elastic IP: Free when attached

### Cost-Saving Tips

1. **Right-size instance** - Don't overprovision
2. **Use gp3 volumes** - 20% cheaper than gp2
3. **Stop during non-business hours** - If possible
4. **Use Reserved Instances** - 30-60% savings for 1-3 year commit
5. **Monitor usage** - Use CloudWatch to track utilization

## Migration from Existing Jenkins

If migrating from an existing Jenkins:

### Option A: Create AMI and Deploy

```bash
# 1. Create AMI from existing Jenkins
aws ec2 create-image \
  --instance-id i-existing-jenkins \
  --name "jenkins-production-$(date +%Y%m%d)" \
  --description "Jenkins production backup"

# 2. Wait for AMI to be available
aws ec2 wait image-available --image-ids ami-xxxxx

# 3. Deploy with Terraform
# Set jenkins_ami_id in terraform.tfvars
terraform apply

# 4. Update DNS to point to new instance

# 5. Verify and decommission old instance
```

### Option B: Attach IAM Profile to Existing

```bash
# Deploy infrastructure without Jenkins
create_jenkins_server = false

# After deployment, attach IAM profile
terraform apply

aws ec2 associate-iam-instance-profile \
  --instance-id i-existing-jenkins \
  --iam-instance-profile Name=$(terraform output -raw jenkins_instance_profile_name)
```

## Next Steps

After Jenkins is deployed:

1. ✓ Access Jenkins web interface
2. ✓ Verify ECS integration
3. ✓ Create Jenkins pipeline
4. ✓ Run test execution
5. ✓ Configure monitoring alerts
6. ✓ Set up regular backups
7. ✓ Document for team

## Summary

The Jenkins module provides:
- ✅ Automated deployment from AMI
- ✅ Pre-configured ECS integration
- ✅ Built-in monitoring and logging
- ✅ Security best practices
- ✅ Optional DNS and backup
- ✅ Flexible configuration

Choose your deployment option and follow the steps above to get Jenkins running!
