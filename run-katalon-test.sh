#!/bin/bash
# Script to run Katalon tests on ECS
# Usage: ./run-katalon-test.sh <test-suite> <target-url>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <test-suite> <target-url> [cluster-name] [task-definition]"
    echo ""
    echo "Example:"
    echo "  $0 smoke-tests https://example.com"
    echo "  $0 regression-tests https://example.com katalon-testing-dev-cluster katalon-testing-dev-katalon"
    exit 1
fi

TEST_SUITE=$1
TARGET_URL=$2

# Get values from Terraform outputs or use defaults
CLUSTER_NAME=${3:-$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")}
TASK_DEFINITION=${4:-$(terraform output -raw katalon_task_definition_family 2>/dev/null || echo "")}

if [ -z "$CLUSTER_NAME" ] || [ -z "$TASK_DEFINITION" ]; then
    echo -e "${RED}Error: Could not determine cluster name or task definition${NC}"
    echo "Please run 'terraform output' to get the values or provide them as arguments"
    exit 1
fi

# Get network configuration from Terraform outputs
echo -e "${YELLOW}Getting network configuration...${NC}"
SUBNETS=$(terraform output -json private_subnet_ids | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')
SECURITY_GROUP=$(terraform output -raw ecs_task_security_group_id)

echo -e "${GREEN}Configuration:${NC}"
echo "  Cluster: $CLUSTER_NAME"
echo "  Task Definition: $TASK_DEFINITION"
echo "  Test Suite: $TEST_SUITE"
echo "  Target URL: $TARGET_URL"
echo ""

# Run the ECS task
echo -e "${YELLOW}Starting ECS task...${NC}"
TASK_ARN=$(aws ecs run-task \
    --cluster "$CLUSTER_NAME" \
    --task-definition "$TASK_DEFINITION" \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
    --overrides "{
        \"containerOverrides\": [{
            \"name\": \"katalon\",
            \"environment\": [
                {\"name\": \"TEST_SUITE\", \"value\": \"$TEST_SUITE\"},
                {\"name\": \"TARGET_URL\", \"value\": \"$TARGET_URL\"},
                {\"name\": \"BUILD_ID\", \"value\": \"$(date +%Y%m%d-%H%M%S)\"}
            ]
        }]
    }" \
    --query 'tasks[0].taskArn' \
    --output text)

if [ -z "$TASK_ARN" ]; then
    echo -e "${RED}Error: Failed to start ECS task${NC}"
    exit 1
fi

echo -e "${GREEN}Task started: $TASK_ARN${NC}"
echo ""

# Extract task ID from ARN
TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')

# Wait for task to complete
echo -e "${YELLOW}Waiting for task to complete...${NC}"
aws ecs wait tasks-stopped --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN"

# Get task exit code
EXIT_CODE=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query 'tasks[0].containers[0].exitCode' \
    --output text)

echo ""
if [ "$EXIT_CODE" = "0" ]; then
    echo -e "${GREEN}✓ Tests completed successfully (exit code: $EXIT_CODE)${NC}"
else
    echo -e "${RED}✗ Tests failed (exit code: $EXIT_CODE)${NC}"
fi

# Show logs location
LOG_GROUP=$(terraform output -raw ecs_cluster_name 2>/dev/null | sed 's/cluster//')
echo ""
echo "View logs with:"
echo "  aws logs tail /ecs/katalon-testing-dev-katalon --follow"
echo ""
echo "Task ARN: $TASK_ARN"
echo "Task ID: $TASK_ID"

exit "$EXIT_CODE"
