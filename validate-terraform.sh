#!/bin/bash
# Terraform validation script for Katalon ECS project
# This ensures you're running validation from the correct directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Terraform Validation Script                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}Current directory: $(pwd)${NC}"
echo ""

# Check if we're in the root module
if [ ! -f "main.tf" ] || [ ! -d "modules" ]; then
    echo -e "${RED}✗ Error: Not in the root Terraform directory${NC}"
    echo -e "${YELLOW}Please run this script from the katalon-ecs-terraform directory${NC}"
    exit 1
fi

echo -e "${GREEN}✓ In correct directory${NC}"
echo ""

# Check for Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform is not installed or not in PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Terraform found: $(terraform version | head -1)${NC}"
echo ""

# Check if terraform has been initialized
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}⚠ Terraform not initialized${NC}"
    echo -e "${YELLOW}Running: terraform init${NC}"
    echo ""
    terraform init
    echo ""
fi

echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Validate all modules
echo -e "${BLUE}[1/6] Validating Root Module...${NC}"
terraform validate
echo -e "${GREEN}✓ Root module valid${NC}"
echo ""

echo -e "${BLUE}[2/6] Validating VPC Module...${NC}"
cd modules/vpc && terraform validate && cd ../..
echo -e "${GREEN}✓ VPC module valid${NC}"
echo ""

echo -e "${BLUE}[3/6] Validating ECS Module...${NC}"
cd modules/ecs && terraform validate && cd ../..
echo -e "${GREEN}✓ ECS module valid${NC}"
echo ""

echo -e "${BLUE}[4/6] Validating IAM Module...${NC}"
cd modules/iam && terraform validate && cd ../..
echo -e "${GREEN}✓ IAM module valid${NC}"
echo ""

echo -e "${BLUE}[5/6] Validating Security Groups Module...${NC}"
cd modules/security-groups && terraform validate && cd ../..
echo -e "${GREEN}✓ Security Groups module valid${NC}"
echo ""

echo -e "${BLUE}[6/6] Validating Jenkins Module...${NC}"
cd modules/jenkins && terraform validate && cd ../..
echo -e "${GREEN}✓ Jenkins module valid${NC}"
echo ""

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Validation Complete!                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}All modules are valid and ready to use!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy terraform.tfvars.example to terraform.tfvars"
echo "2. Update terraform.tfvars with your values"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
