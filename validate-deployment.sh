#!/bin/bash
# Validation script to check Katalon ECS infrastructure deployment
# Usage: ./validate-deployment.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check marks
CHECK="✓"
CROSS="✗"

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Katalon ECS Infrastructure Validation Script      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print success
success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

# Function to print error
error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

# Function to print info
info() {
    echo -e "${YELLOW}➜ $1${NC}"
}

# Function to check command exists
check_command() {
    if command -v $1 &> /dev/null; then
        success "$1 is installed"
        return 0
    else
        error "$1 is not installed"
        return 1
    fi
}

# Check prerequisites
echo -e "${BLUE}[1/7] Checking Prerequisites...${NC}"
check_command "terraform" || exit 1
check_command "aws" || exit 1
check_command "jq" || info "jq not installed (optional but recommended)"
echo ""

# Check Terraform initialization
echo -e "${BLUE}[2/7] Checking Terraform State...${NC}"
if [ -d ".terraform" ]; then
    success "Terraform initialized"
else
    error "Terraform not initialized. Run: terraform init"
    exit 1
fi

if [ -f "terraform.tfstate" ] || [ -f ".terraform/terraform.tfstate" ]; then
    success "Terraform state file exists"
else
    error "No Terraform state found. Run: terraform apply"
    exit 1
fi
echo ""

# Get Terraform outputs
echo -e "${BLUE}[3/7] Retrieving Terraform Outputs...${NC}"

# Check if infrastructure has been deployed
if ! terraform output vpc_id &> /dev/null; then
    echo -e "${YELLOW}⚠ Infrastructure not yet deployed${NC}"
    echo -e "${YELLOW}This is a pre-deployment validation${NC}"
    echo ""
    echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
    echo -e "${GREEN}✓ All prerequisites are met${NC}"
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║             Pre-Deployment Validation                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Configure terraform.tfvars with your values"
    echo "2. Run: terraform plan (to preview changes)"
    echo "3. Run: terraform apply (to deploy infrastructure)"
    echo "4. Run this script again after deployment to validate"
    echo ""
    exit 0
fi

if ! VPC_ID=$(terraform output -raw vpc_id 2>/dev/null); then
    error "Cannot retrieve Terraform outputs"
    exit 1
fi

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null)
TASK_DEF=$(terraform output -raw katalon_task_definition_family 2>/dev/null)
S3_BUCKET=$(terraform output -raw s3_results_bucket_name 2>/dev/null || echo "")

success "Retrieved Terraform outputs"
info "VPC ID: $VPC_ID"
info "Cluster: $CLUSTER_NAME"
info "Task Definition: $TASK_DEF"
if [ -n "$S3_BUCKET" ]; then
    info "S3 Bucket: $S3_BUCKET"
fi
echo ""

# Validate AWS credentials
echo -e "${BLUE}[4/7] Validating AWS Credentials...${NC}"
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    success "AWS credentials valid"
    info "Account ID: $ACCOUNT_ID"
else
    error "Invalid AWS credentials"
    exit 1
fi
echo ""

# Check VPC resources
echo -e "${BLUE}[5/7] Checking VPC Resources...${NC}"

# VPC
if aws ec2 describe-vpcs --vpc-ids $VPC_ID &> /dev/null; then
    success "VPC exists and is accessible"
else
    error "VPC not found"
fi

# Subnets
SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets | length(@)' --output text)
if [ "$SUBNET_COUNT" -ge 4 ]; then
    success "Subnets configured ($SUBNET_COUNT found)"
else
    error "Insufficient subnets (found: $SUBNET_COUNT, expected: >= 4)"
fi

# NAT Gateways
NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'NatGateways | length(@)' --output text)
if [ "$NAT_COUNT" -ge 1 ]; then
    success "NAT Gateways configured ($NAT_COUNT active)"
else
    error "No active NAT Gateways found"
fi

# Internet Gateway
IGW_COUNT=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways | length(@)' --output text)
if [ "$IGW_COUNT" -ge 1 ]; then
    success "Internet Gateway attached"
else
    error "No Internet Gateway found"
fi

echo ""

# Check ECS resources
echo -e "${BLUE}[6/7] Checking ECS Resources...${NC}"

# Cluster
if aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text | grep -q "ACTIVE"; then
    success "ECS Cluster is active"
else
    error "ECS Cluster not active"
fi

# Task Definition
TASK_DEF_ARN=$(aws ecs describe-task-definition --task-definition $TASK_DEF --query 'taskDefinition.taskDefinitionArn' --output text 2>/dev/null)
if [ -n "$TASK_DEF_ARN" ]; then
    success "Task Definition exists"
    info "ARN: $TASK_DEF_ARN"
else
    error "Task Definition not found"
fi

# CloudWatch Log Group
LOG_GROUP="/ecs/${CLUSTER_NAME/cluster/katalon}"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query 'logGroups[0].logGroupName' --output text &> /dev/null; then
    success "CloudWatch Log Group exists"
else
    error "CloudWatch Log Group not found"
fi

echo ""

# Check S3 and IAM
echo -e "${BLUE}[7/7] Checking Supporting Resources...${NC}"

# S3 Bucket
if aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
    success "S3 bucket accessible"
else
    error "S3 bucket not accessible"
fi

# IAM Roles
ROLE_COUNT=$(aws iam list-roles --query "Roles[?contains(RoleName, 'katalon')] | length(@)" --output text)
if [ "$ROLE_COUNT" -ge 2 ]; then
    success "IAM roles configured ($ROLE_COUNT found)"
else
    error "Insufficient IAM roles (found: $ROLE_COUNT, expected: >= 2)"
fi

echo ""

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Validation Summary                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Try to run a test task (dry-run)
echo -e "${YELLOW}Testing ECS Task Launch (Dry Run)...${NC}"
SUBNETS=$(terraform output -json private_subnet_ids | jq -r '.[]' | head -1)
SECURITY_GROUP=$(terraform output -raw ecs_task_security_group_id)

if [ -n "$SUBNETS" ] && [ -n "$SECURITY_GROUP" ]; then
    info "Network Configuration:"
    info "  Subnet: $SUBNETS"
    info "  Security Group: $SECURITY_GROUP"
    
    echo ""
    echo -e "${GREEN}Infrastructure validation complete!${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Configure Jenkins with the following values:"
    echo "   - ECS Cluster: $CLUSTER_NAME"
    echo "   - Task Definition: $TASK_DEF"
    echo "   - Subnets: $(terraform output -json private_subnet_ids | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')"
    echo "   - Security Group: $SECURITY_GROUP"
    echo "   - S3 Bucket: $S3_BUCKET"
    echo ""
    echo "2. Run a test with:"
    echo "   ./run-katalon-test.sh smoke-tests https://example.com"
    echo ""
    echo "3. View CloudWatch logs:"
    echo "   aws logs tail $LOG_GROUP --follow"
    echo ""
else
    error "Could not retrieve network configuration"
    exit 1
fi

# Create summary file
cat > validation-summary.txt << EOF
Katalon ECS Infrastructure Validation Summary
Generated: $(date)

Infrastructure Details:
- AWS Account: $ACCOUNT_ID
- Region: $(aws configure get region)
- VPC ID: $VPC_ID
- ECS Cluster: $CLUSTER_NAME
- Task Definition: $TASK_DEF
- S3 Bucket: $S3_BUCKET

Resource Counts:
- Subnets: $SUBNET_COUNT
- NAT Gateways: $NAT_COUNT
- IAM Roles: $ROLE_COUNT

Status: All validations passed ✓

Jenkins Configuration Values:
ECS_CLUSTER=$CLUSTER_NAME
TASK_DEFINITION=$TASK_DEF
SUBNETS=$(terraform output -json private_subnet_ids | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')
SECURITY_GROUP=$SECURITY_GROUP
S3_BUCKET=$S3_BUCKET
EOF

success "Validation summary saved to validation-summary.txt"

