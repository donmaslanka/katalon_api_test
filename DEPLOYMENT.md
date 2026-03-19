# Deployment Guide

## Pre-Deployment Checklist

- [ ] AWS CLI installed and configured
- [ ] Terraform v1.0+ installed
- [ ] Access to AWS account 318798562215
- [ ] Jenkins server private IP address noted
- [ ] AWS credentials configured (`aws configure`)

## Step-by-Step Deployment

### 1. Prepare Configuration

```bash
# Navigate to project directory
cd katalon-ecs-terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration with your values
# IMPORTANT: Update jenkins_server_ip with actual IP
nano terraform.tfvars  # or use your preferred editor
```

### 2. Initialize Terraform

```bash
# Download required providers
terraform init

# Expected output: "Terraform has been successfully initialized!"
```

### 3. Validate Configuration

```bash
# Validate Terraform syntax
terraform validate

# Expected output: "Success! The configuration is valid."

# Format code (optional but recommended)
terraform fmt -recursive
```

### 4. Review Infrastructure Plan

```bash
# Generate and review execution plan
terraform plan

# Review the output carefully
# Expected resources to be created: ~30-40 resources
```

### 5. Deploy Infrastructure

```bash
# Apply configuration
terraform apply

# Review the plan one more time
# Type 'yes' when prompted

# This will take approximately 5-10 minutes
```

### 6. Capture Outputs

```bash
# Save important outputs
terraform output > deployment-outputs.txt

# View Jenkins integration details
terraform output jenkins_integration_info

# Save specific values for Jenkins configuration
echo "ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)" > jenkins-config.env
echo "TASK_DEFINITION=$(terraform output -raw katalon_task_definition_family)" >> jenkins-config.env
echo "SUBNETS=$(terraform output -json private_subnet_ids | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')" >> jenkins-config.env
echo "SECURITY_GROUP=$(terraform output -raw ecs_task_security_group_id)" >> jenkins-config.env
echo "S3_BUCKET=$(terraform output -raw s3_results_bucket_name)" >> jenkins-config.env
```

## Post-Deployment Configuration

### Configure Jenkins EC2 Instance

#### Option A: Attach IAM Instance Profile (Recommended)

```bash
# Get instance profile name
INSTANCE_PROFILE=$(terraform output -raw jenkins_instance_profile_name)

# Get your Jenkins EC2 instance ID (replace with actual ID)
JENKINS_INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"

# Attach instance profile
aws ec2 associate-iam-instance-profile \
  --instance-id $JENKINS_INSTANCE_ID \
  --iam-instance-profile Name=$INSTANCE_PROFILE

# Verify attachment
aws ec2 describe-iam-instance-profile-associations \
  --filters Name=instance-id,Values=$JENKINS_INSTANCE_ID
```

#### Option B: Create IAM User (Alternative)

If you can't modify the Jenkins EC2 instance profile:

```bash
# Create IAM user for Jenkins
aws iam create-user --user-name jenkins-ecs-user

# Attach policy (use the policy ARN from IAM module output)
aws iam attach-user-policy \
  --user-name jenkins-ecs-user \
  --policy-arn <policy-arn-from-output>

# Create access keys
aws iam create-access-key --user-name jenkins-ecs-user

# Configure these credentials in Jenkins
```

### Configure Jenkins

#### 1. Install Required Plugins

In Jenkins, install:
- AWS Steps Plugin
- Pipeline AWS Plugin
- CloudBees AWS Credentials Plugin

#### 2. Add AWS Credentials

1. Navigate to: Jenkins → Manage Jenkins → Credentials
2. Add credentials:
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Access Key ID: (from IAM user or instance profile)
   - Secret Access Key: (from IAM user)

#### 3. Add Configuration Credentials

Add the following as "Secret text" credentials:

```
ID: ecs-cluster-name
Secret: <value from terraform output>

ID: ecs-task-definition  
Secret: <value from terraform output>

ID: ecs-subnets
Secret: <comma-separated subnet IDs>

ID: ecs-security-group
Secret: <security group ID>

ID: s3-results-bucket
Secret: <S3 bucket name>
```

#### 4. Create Jenkins Pipeline Job

1. New Item → Pipeline
2. Configure:
   - Name: `Katalon-ECS-Tests`
   - Pipeline Definition: Pipeline script from SCM
   - Repository URL: (your Git repo)
   - Script Path: `Jenkinsfile`

Or paste the Jenkinsfile content directly into the pipeline script section.

#### 5. Test Jenkins Integration

```bash
# Trigger a test build
curl -X POST http://jenkins-url/job/Katalon-ECS-Tests/buildWithParameters \
  --user admin:token \
  --data-urlencode 'TEST_SUITE=smoke-tests' \
  --data-urlencode 'TARGET_URL=https://example.com'
```

## Verification Steps

### 1. Verify VPC

```bash
# Check VPC
VPC_ID=$(terraform output -raw vpc_id)
aws ec2 describe-vpcs --vpc-ids $VPC_ID

# Check subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"

# Check NAT gateways
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID"
```

### 2. Verify ECS Cluster

```bash
# Check cluster
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
aws ecs describe-clusters --clusters $CLUSTER_NAME

# Check task definition
TASK_DEF=$(terraform output -raw katalon_task_definition_family)
aws ecs describe-task-definition --task-definition $TASK_DEF
```

### 3. Verify IAM Roles

```bash
# List roles
aws iam list-roles --query 'Roles[?contains(RoleName, `katalon`)].RoleName'

# Check role policies
aws iam list-attached-role-policies --role-name <role-name>
```

### 4. Verify S3 Bucket

```bash
# Check bucket
BUCKET=$(terraform output -raw s3_results_bucket_name)
aws s3 ls s3://$BUCKET
```

### 5. Run Test Task

```bash
# Use the helper script
./run-katalon-test.sh smoke-tests https://example.com

# Or manually
aws ecs run-task \
  --cluster $CLUSTER_NAME \
  --task-definition $TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet-ids>],securityGroups=[<sg-id>],assignPublicIp=DISABLED}"
```

## Troubleshooting

### Issue: Terraform init fails

```bash
# Clear cache and retry
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Issue: Task fails to start

```bash
# Check task definition
aws ecs describe-task-definition --task-definition $TASK_DEF

# Check for stopped tasks
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks <task-arn>

# Common issues:
# - Insufficient memory/CPU
# - Invalid container image
# - Network connectivity issues
```

### Issue: Can't pull Docker image

```bash
# Check ECR permissions
aws ecr get-login-password --region us-east-1

# Check task execution role
aws iam get-role-policy \
  --role-name <execution-role-name> \
  --policy-name ecr-policy
```

### Issue: Network connectivity

```bash
# Verify NAT gateway is active
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" \
  --query 'NatGateways[*].[NatGatewayId,State]'

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID"

# Verify VPC endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID"
```

### Issue: Jenkins can't trigger tasks

```bash
# Verify instance profile
aws ec2 describe-iam-instance-profile-associations \
  --filters Name=instance-id,Values=$JENKINS_INSTANCE_ID

# Test IAM permissions from Jenkins server
aws ecs list-clusters
aws ecs describe-task-definition --task-definition $TASK_DEF

# Check CloudWatch logs from Jenkins
aws logs describe-log-groups --log-group-name-prefix /ecs/
```

## Rollback Procedure

If deployment fails or needs to be reverted:

```bash
# Destroy all resources
terraform destroy

# Review what will be destroyed
# Type 'yes' to confirm

# Clean up state
rm -f terraform.tfstate terraform.tfstate.backup
```

## Updates and Maintenance

### Updating Task Definition

```bash
# Modify task definition in modules/ecs/main.tf
# For example, change memory or CPU

# Apply changes
terraform apply -target=module.ecs.aws_ecs_task_definition.katalon
```

### Adding New Environments

```bash
# Create new tfvars file
cp terraform.tfvars environments/staging.tfvars

# Edit environment-specific values
nano environments/staging.tfvars

# Deploy staging
terraform apply -var-file=environments/staging.tfvars
```

### Scaling Resources

To handle more concurrent tests:

```bash
# Edit terraform.tfvars
katalon_cpu    = 4096  # Increase CPU
katalon_memory = 8192  # Increase memory

# Apply changes
terraform apply
```

## Security Best Practices

1. **Never commit terraform.tfvars** - Contains sensitive data
2. **Use remote state** - Configure S3 backend for team collaboration
3. **Enable MFA** - For AWS console access
4. **Rotate credentials** - Regularly rotate IAM access keys
5. **Review IAM policies** - Ensure least privilege
6. **Enable CloudTrail** - Audit all AWS API calls
7. **Use VPC Flow Logs** - Monitor network traffic

## Next Steps

After successful deployment:

1. ✓ Verify all resources are created
2. ✓ Configure Jenkins with outputs
3. ✓ Run test execution
4. ✓ Monitor CloudWatch logs
5. ✓ Set up alerts and monitoring
6. ✓ Document custom test suites
7. ✓ Train team on usage

## Support

For issues:
1. Check CloudWatch Logs: `/ecs/<project>-<env>-katalon`
2. Review Terraform state: `terraform show`
3. Check AWS Console for resource status
4. Review this deployment guide

## Appendix: Useful Commands

```bash
# Quick status check
terraform state list | grep -E "ecs|vpc|iam"

# Get all outputs
terraform output -json | jq

# Refresh state
terraform refresh

# Show specific resource
terraform state show module.ecs.aws_ecs_cluster.main

# Import existing resource
terraform import module.vpc.aws_vpc.main vpc-xxxxx

# Validate without accessing remote state
terraform validate
```
