# Katalon ECS Testing Infrastructure

This Terraform project creates a complete AWS infrastructure for running Katalon automated tests in ECS Fargate containers, integrated with an existing Jenkins server.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Account                          │
│                       (318798562215)                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Custom VPC (10.0.0.0/16)              │ │
│  │                                                         │ │
│  │  ┌──────────────┐            ┌──────────────┐         │ │
│  │  │   Public     │            │   Public     │         │ │
│  │  │   Subnet     │            │   Subnet     │         │ │
│  │  │ (10.0.1.0/24)│            │ (10.0.2.0/24)│         │ │
│  │  │              │            │              │         │ │
│  │  │  NAT Gateway │            │  NAT Gateway │         │ │
│  │  └──────┬───────┘            └──────┬───────┘         │ │
│  │         │                           │                  │ │
│  │  ┌──────▼───────┐            ┌──────▼───────┐         │ │
│  │  │   Private    │            │   Private    │         │ │
│  │  │   Subnet     │            │   Subnet     │         │ │
│  │  │(10.0.10.0/24)│            │(10.0.11.0/24)│         │ │
│  │  │              │            │              │         │ │
│  │  │  ECS Tasks   │            │  ECS Tasks   │         │ │
│  │  │  (Katalon)   │            │  (Katalon)   │         │ │
│  │  └──────────────┘            └──────────────┘         │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ ECS Cluster    │  │ S3 Bucket       │  │ CloudWatch   │ │
│  │ (Fargate)      │  │ (Test Results)  │  │ (Logs)       │ │
│  └────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                              │
│  Existing Jenkins EC2 → Triggers ECS Tasks via AWS API      │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Modular Terraform Design**: Reusable modules for VPC, ECS, IAM, and Security Groups
- **Complete Networking**: Custom VPC with public/private subnets, NAT gateways, and VPC endpoints
- **ECS Fargate**: Serverless container execution for cost efficiency
- **Jenkins Integration**: IAM roles and policies for Jenkins to trigger ECS tasks
- **Security**: Proper security groups, private subnets, and least-privilege IAM roles
- **Logging**: CloudWatch Logs integration for all container output
- **Test Results Storage**: S3 bucket with lifecycle policies for test results
- **Cost Optimization**: VPC endpoints to reduce NAT gateway costs

## Prerequisites

1. **AWS Account**: Access to account `318798562215`
2. **AWS CLI**: Configured with appropriate credentials
3. **Terraform**: Version 1.0 or higher
4. **Jenkins Server**: 
   - Option A: Use existing EC2 instance (will need its private IP)
   - Option B: Create new Jenkins server from AMI using the Jenkins module
5. **SSH Key Pair**: For Jenkins EC2 access (if creating new Jenkins server)

## Project Structure

```
katalon-ecs-terraform/
├── main.tf                      # Root module configuration
├── variables.tf                 # Root variable definitions
├── outputs.tf                   # Root outputs
├── terraform.tfvars.example     # Example variable values
├── modules/
│   ├── vpc/                     # VPC module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecs/                     # ECS module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/                     # IAM module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security-groups/         # Security Groups module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── jenkins/                 # Jenkins module (optional)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── user-data.sh
│       └── README.md
└── README.md
```

## Quick Start

### 1. Clone and Configure

```bash
cd katalon-ecs-terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

Update the following values in `terraform.tfvars`:

```hcl
# Required: Update with your Jenkins server's private IP
jenkins_server_ip = "10.0.5.100/32"  # Replace with actual IP

# Optional: Customize other values
aws_region     = "us-east-1"
project_name   = "katalon-testing"
environment    = "dev"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

Review the changes and type `yes` to confirm.

## Jenkins Configuration

After deploying the infrastructure, you'll need to configure Jenkins to trigger ECS tasks.

### Option 1: Attach IAM Instance Profile

1. Get the instance profile name from Terraform output:
   ```bash
   terraform output jenkins_integration_info
   ```

2. Attach the instance profile to your Jenkins EC2 instance:
   ```bash
   aws ec2 associate-iam-instance-profile \
     --instance-id i-xxxxxxxxxxxxx \
     --iam-instance-profile Name=<instance-profile-name>
   ```

### Option 2: Jenkins Pipeline Example

Create a Jenkins pipeline job with the following script:

```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'TEST_SUITE', defaultValue: 'smoke-tests', description: 'Test suite to run')
        string(name: 'TARGET_URL', defaultValue: 'https://example.com', description: 'Target website URL')
    }
    
    environment {
        AWS_REGION = 'us-east-1'
        ECS_CLUSTER = '<cluster-name-from-output>'
        TASK_DEFINITION = '<task-definition-from-output>'
        SUBNETS = '<subnet-ids-from-output>'
        SECURITY_GROUP = '<security-group-from-output>'
    }
    
    stages {
        stage('Run Katalon Tests') {
            steps {
                script {
                    // Run ECS task
                    def taskArn = sh(
                        script: """
                            aws ecs run-task \\
                                --cluster ${ECS_CLUSTER} \\
                                --task-definition ${TASK_DEFINITION} \\
                                --launch-type FARGATE \\
                                --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SECURITY_GROUP}],assignPublicIp=DISABLED}" \\
                                --overrides '{
                                    "containerOverrides": [{
                                        "name": "katalon",
                                        "environment": [
                                            {"name": "TEST_SUITE", "value": "${params.TEST_SUITE}"},
                                            {"name": "TARGET_URL", "value": "${params.TARGET_URL}"}
                                        ]
                                    }]
                                }' \\
                                --query 'tasks[0].taskArn' \\
                                --output text
                        """,
                        returnStdout: true
                    ).trim()
                    
                    echo "Started ECS task: ${taskArn}"
                    
                    // Wait for task completion
                    sh """
                        aws ecs wait tasks-stopped \\
                            --cluster ${ECS_CLUSTER} \\
                            --tasks ${taskArn}
                    """
                    
                    // Check task exit code
                    def exitCode = sh(
                        script: """
                            aws ecs describe-tasks \\
                                --cluster ${ECS_CLUSTER} \\
                                --tasks ${taskArn} \\
                                --query 'tasks[0].containers[0].exitCode' \\
                                --output text
                        """,
                        returnStdout: true
                    ).trim()
                    
                    if (exitCode != '0') {
                        error("Katalon tests failed with exit code: ${exitCode}")
                    }
                }
            }
        }
        
        stage('Retrieve Results') {
            steps {
                script {
                    // Download test results from S3
                    sh """
                        aws s3 sync s3://<s3-bucket-from-output>/\${BUILD_NUMBER}/ ./test-results/
                    """
                    
                    // Publish results
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'test-results',
                        reportFiles: 'report.html',
                        reportName: 'Katalon Test Report'
                    ])
                }
            }
        }
    }
}
```

### Option 3: AWS CLI Direct Execution

Run tests directly from command line:

```bash
# Get values from Terraform output
terraform output jenkins_integration_info

# Run task
aws ecs run-task \
  --cluster katalon-testing-dev-cluster \
  --task-definition katalon-testing-dev-katalon \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-zzz],assignPublicIp=DISABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "katalon",
      "environment": [
        {"name": "TEST_SUITE", "value": "smoke-tests"},
        {"name": "TARGET_URL", "value": "https://example.com"}
      ]
    }]
  }'
```

## Customization

### Adjust Container Resources

In `terraform.tfvars`:

```hcl
katalon_cpu    = 4096  # 4 vCPU
katalon_memory = 8192  # 8 GB
```

### Use Custom Katalon Image

If you have a custom Katalon Docker image in ECR:

```hcl
katalon_image = "318798562215.dkr.ecr.us-east-1.amazonaws.com/my-katalon:latest"
```

### Multi-Environment Setup

Create environment-specific variable files:

```bash
# Development
terraform apply -var-file="environments/dev/terraform.tfvars"

# Staging
terraform apply -var-file="environments/staging/terraform.tfvars"

# Production
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## Cost Optimization

- **VPC Endpoints**: Included to reduce NAT Gateway data transfer costs
- **Fargate Spot**: Can be enabled for cost savings (may have interruptions)
- **S3 Lifecycle**: Automatically deletes old test results after 90 days
- **CloudWatch Logs**: Retention set to 7 days (adjust as needed)

### Estimated Monthly Costs (Development)

- **VPC**: NAT Gateways (~$64/month for 2 AZs)
- **ECS Fargate**: $0 when not running, ~$0.04/hour when running (2vCPU, 4GB)
- **S3 Storage**: ~$0.023/GB
- **CloudWatch Logs**: ~$0.50/GB ingested
- **VPC Endpoints**: ~$7/month per endpoint

## Monitoring

### CloudWatch Logs

View container logs:
```bash
aws logs tail /ecs/katalon-testing-dev-katalon --follow
```

### ECS Task Monitoring

```bash
# List running tasks
aws ecs list-tasks --cluster katalon-testing-dev-cluster

# Describe task
aws ecs describe-tasks --cluster katalon-testing-dev-cluster --tasks <task-arn>
```

### S3 Test Results

```bash
# List test results
aws s3 ls s3://<bucket-name>/

# Download results
aws s3 sync s3://<bucket-name>/test-run-123/ ./local-results/
```

## Security Considerations

1. **Network Isolation**: ECS tasks run in private subnets with no direct internet access
2. **Least Privilege**: IAM roles follow least privilege principle
3. **Encryption**: S3 bucket encrypted at rest
4. **Logging**: All activities logged to CloudWatch
5. **VPC Endpoints**: Direct AWS service access without internet routing

## Troubleshooting

### Task Fails to Start

Check security groups and subnet configuration:
```bash
aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> --query 'tasks[0].stopCode'
```

### Can't Pull Docker Image

Verify IAM task execution role has ECR permissions:
```bash
aws iam get-role-policy --role-name <execution-role> --policy-name ecr-policy
```

### Network Connectivity Issues

Check NAT Gateway status:
```bash
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<vpc-id>
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including test results in S3.

## Support and Contributing

For issues or questions:
1. Check Terraform documentation: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
2. Review AWS ECS documentation: https://docs.aws.amazon.com/ecs/
3. Check Katalon documentation: https://docs.katalon.com/

## License

This project is provided as-is for internal use.
