# Quick Start Guide

Get your Katalon ECS testing infrastructure up and running in 15 minutes!

## Prerequisites Checklist

```bash
# Verify prerequisites
terraform --version    # Should be >= 1.0
aws --version         # AWS CLI v2
aws sts get-caller-identity  # Verify AWS access
```

## 5-Step Deployment

### Step 1: Configure (2 minutes)

```bash
# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars

# Edit these critical values:
# - jenkins_server_ip: Your Jenkins EC2 private IP
nano terraform.tfvars
```

### Step 2: Initialize (1 minute)

```bash
terraform init
```

### Step 3: Plan (2 minutes)

```bash
terraform plan
# Review: Should create ~35-40 resources
```

### Step 4: Deploy (5-10 minutes)

```bash
terraform apply
# Type 'yes' when prompted
```

### Step 5: Validate (2 minutes)

```bash
# Run validation
./validate-deployment.sh

# Save outputs
terraform output > outputs.txt
```

## Quick Test

Test your infrastructure immediately:

```bash
# Run a test task
./run-katalon-test.sh smoke-tests https://example.com

# Watch logs
aws logs tail /ecs/katalon-testing-dev-katalon --follow
```

## Configure Jenkins (5 minutes)

### Get Configuration Values

```bash
# These values go into Jenkins credentials
echo "Cluster: $(terraform output -raw ecs_cluster_name)"
echo "Task Def: $(terraform output -raw katalon_task_definition_family)"
echo "Subnets: $(terraform output -json private_subnet_ids | jq -r '.[]' | tr '\n' ',')"
echo "SG: $(terraform output -raw ecs_task_security_group_id)"
echo "Bucket: $(terraform output -raw s3_results_bucket_name)"
```

### Attach IAM Role to Jenkins

```bash
# Get Jenkins instance ID
JENKINS_ID="i-xxxxxxxxx"  # Your Jenkins EC2 instance ID

# Attach profile
aws ec2 associate-iam-instance-profile \
  --instance-id $JENKINS_ID \
  --iam-instance-profile Name=$(terraform output -raw jenkins_instance_profile_name)
```

### Create Jenkins Pipeline

1. Jenkins → New Item → Pipeline
2. Name: `Katalon-Tests`
3. Copy content from `Jenkinsfile`
4. Add credentials (from outputs above)
5. Save and Build!

## Architecture at a Glance

```
Internet
   ↓
Internet Gateway
   ↓
Public Subnets (NAT Gateways)
   ↓
Private Subnets (ECS Tasks)
   ↓
Public Websites (Test Targets)

Storage: S3 Bucket (Test Results)
Logging: CloudWatch Logs
Compute: ECS Fargate (On-Demand)
```

## Common Commands

```bash
# View all outputs
terraform output

# View logs
aws logs tail /ecs/<project>-<env>-katalon --follow

# List running tasks
aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name)

# Check S3 results
aws s3 ls s3://$(terraform output -raw s3_results_bucket_name)/

# Destroy everything
terraform destroy
```

## What Was Created?

- ✓ VPC with public/private subnets across 2 AZs
- ✓ NAT Gateways for internet access
- ✓ VPC Endpoints for AWS services (cost savings)
- ✓ ECS Fargate cluster
- ✓ Katalon task definition
- ✓ IAM roles and policies
- ✓ Security groups
- ✓ S3 bucket for test results
- ✓ CloudWatch log groups

## Troubleshooting

### Issue: Task won't start
```bash
# Check task definition
aws ecs describe-task-definition --task-definition $(terraform output -raw katalon_task_definition_family)
```

### Issue: Network connectivity
```bash
# Verify NAT gateways
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$(terraform output -raw vpc_id)
```

### Issue: Permission denied
```bash
# Check IAM role attachment
aws ec2 describe-iam-instance-profile-associations --filters Name=instance-id,Values=<jenkins-id>
```

## Cost Estimate

**Development Environment (Low Usage):**
- NAT Gateways: ~$64/month
- ECS Fargate: ~$0 (only when running)
- S3 Storage: ~$1/month
- VPC Endpoints: ~$21/month
- **Total: ~$85-90/month**

## Next Steps

1. ✓ Infrastructure deployed
2. → Configure Jenkins pipeline
3. → Create test suites in Katalon
4. → Run first automated test
5. → Set up monitoring/alerts
6. → Train team on usage

## Need Help?

- Full documentation: See `README.md`
- Deployment guide: See `DEPLOYMENT.md`
- Validation script: `./validate-deployment.sh`
- Test runner: `./run-katalon-test.sh`

## Project Structure

```
katalon-ecs-terraform/
├── README.md              ← Full documentation
├── DEPLOYMENT.md          ← Detailed deployment guide
├── QUICKSTART.md          ← You are here!
├── main.tf                ← Root configuration
├── variables.tf           ← Variable definitions
├── outputs.tf             ← Output definitions
├── terraform.tfvars       ← Your configuration (gitignored)
├── Jenkinsfile            ← Jenkins pipeline
├── run-katalon-test.sh    ← Test runner script
├── validate-deployment.sh ← Validation script
└── modules/               ← Reusable modules
    ├── vpc/
    ├── ecs/
    ├── iam/
    └── security-groups/
```

---

**You're all set! 🚀**

For detailed information, see the full `README.md` and `DEPLOYMENT.md` files.
