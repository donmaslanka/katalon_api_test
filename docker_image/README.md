# Katalon on ECS — Jenkins pipeline

Run Katalon test suites on AWS ECS Fargate, triggered from a Jenkins pipeline running on an EC2 agent.

---

## How it works

```
GitHub repo (Jenkinsfile)
        │
        ▼ pipeline trigger
Jenkins EC2 agent
  • runs aws cli only
  • needs: aws cli, IAM instance profile
        │
        │  aws ecs run-task  (Fargate, --overrides passes katalonc args)
        ▼
ECS Fargate task  ──pulls image──▶  ECR
  katalon-container                 katalon-test-runner:<tag>
  ENTRYPOINT: katalonc                  (built from docker_image/Dockerfile)
        │
        ├──logs──▶  CloudWatch  /ecs/katalon-testing-dev-katalon
        └──results▶  Katalon TestOps  (org 2333388, API key auth)
```

The Jenkins EC2 agent does **not** run Katalon directly. It only calls the AWS API. Katalon runs inside the Fargate container and reports results to Katalon TestOps. Jenkins blocks on `aws ecs wait tasks-stopped` and then checks the container exit code to determine pass/fail.

---

## Prerequisites

### AWS infrastructure (Terraform)

```bash
cd <repo-root>
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init
terraform apply
```

Terraform creates: VPC + subnets, ECS cluster, Fargate task definition, IAM roles, CloudWatch log group, S3 bucket for results, and (optionally) the Jenkins EC2 instance.

After `terraform apply`, note the outputs — you will need the subnet IDs and security group ID for the Jenkins pipeline parameters.

### Jenkins

1. **Agent label** — the EC2 instance must be registered as a Jenkins agent with the label `ec2-agent` (or update the `agent { label ... }` line in the Jenkinsfile).
2. **IAM instance profile** — the EC2 must have an instance profile that allows `ecs:RunTask`, `ecs:DescribeTasks`, `ecs:StopTask`, and `iam:PassRole` on the ECS execution and task roles. Terraform creates this profile as part of `modules/iam`.
3. **Credential** — add a *Secret Text* credential in Jenkins with ID `katalon-api-key`. The value is your Katalon API key (with or without the `apiKey=` prefix — the pipeline strips it).
4. **Pipeline job** — create a Pipeline job pointing at this repo. Set *Script Path* to `Jenkinsfile`.

### Docker image

The Katalon project is baked into the image at build time.

```bash
cd docker_image
IMAGE=318798562215.dkr.ecr.us-west-2.amazonaws.com/katalon-test-runner

# Authenticate to ECR
aws ecr get-login-password --region us-west-2 \
  | docker login --username AWS --password-stdin \
      318798562215.dkr.ecr.us-west-2.amazonaws.com

# Build and push
docker build -t $IMAGE:my-tag .
docker push $IMAGE:my-tag
```

Then update `katalon_image` in `terraform.tfvars` and run `terraform apply` to register a new task definition revision, or register it manually:

```bash
# Edit katalon-task-def.json to point at your new image tag, then:
aws ecs register-task-definition \
  --cli-input-json file://katalon-task-def.json \
  --region us-west-2
```

---

## Running tests

Trigger the Jenkins pipeline manually or via webhook. The available parameters are:

| Parameter | Default | Description |
|---|---|---|
| `TEST_SUITE` | `Test Suites/Smoke` | Suite path inside the container. Short form `Smoke` is also accepted. |
| `KATALON_PROJECT_PATH` | `/katalon/project` | Project path inside the container. Matches the Dockerfile `WORKDIR`. |
| `SUBNET_IDS` | `subnet-0968b2a4486c2c297` | Private subnet(s) for the Fargate task. From Terraform output `private_subnet_ids`. |
| `SECURITY_GROUP_IDS` | `sg-014254f1dc8168a1a` | Security group(s). From Terraform output `ecs_task_security_group_id`. |
| `ASSIGN_PUBLIC_IP` | `DISABLED` | `DISABLED` for private subnets. `ENABLED` only if the subnet has no NAT gateway. |

---

## Viewing logs

After a run, the pipeline prints the exact CloudWatch log stream path:

```
ecs/katalon-container/<task-id>
```

Fetch logs directly:

```bash
aws logs get-log-events \
  --log-group-name /ecs/katalon-testing-dev-katalon \
  --log-stream-name ecs/katalon-container/<task-id> \
  --region us-west-2
```

Or open the CloudWatch console — the pipeline prints a direct link in the build log.

---

## Repository layout

```
.
├── Jenkinsfile                  # Pipeline definition — only file Jenkins reads
├── katalon-task-def.json        # ECS task definition (reference / manual registration)
├── terraform.tfvars             # Your environment values (gitignored in prod)
├── terraform.tfvars.example     # Template — copy and fill in
├── main.tf                      # Root Terraform config, wires modules together
├── variables.tf                 # Root variable declarations
├── outputs.tf                   # Terraform outputs (subnet IDs, SG IDs, etc.)
├── docker_image/
│   ├── Dockerfile               # Builds the Katalon runner image pushed to ECR
│   └── BUILD.md                 # Docker build / push instructions
└── modules/
    ├── ecs/                     # ECS cluster, Fargate task definition, S3 bucket
    ├── iam/                     # IAM roles for ECS tasks and Jenkins EC2
    ├── jenkins/                 # Jenkins EC2 instance (optional)
    ├── security-groups/         # Security groups for ECS tasks
    └── vpc/                     # VPC, subnets, NAT gateway
```

---

## Key AWS resource names

| Resource | Name |
|---|---|
| ECS cluster | `katalon-testing-dev-cluster` |
| Task definition | `katalon-testing-dev-katalon` |
| Container name | `katalon-container` |
| ECR repo | `318798562215.dkr.ecr.us-west-2.amazonaws.com/katalon-test-runner` |
| CloudWatch log group | `/ecs/katalon-testing-dev-katalon` |
| AWS region | `us-west-2` |
| AWS account | `318798562215` |

---

## Troubleshooting

**`ECS run-task returned no taskArn`**
- Verify the EC2 instance profile has `ecs:RunTask` and `iam:PassRole` on the execution and task roles.
- Check that the task definition family name in the Jenkinsfile matches the registered definition exactly: `katalon-testing-dev-katalon`.

**Task exits immediately with code 1**
- The container command is wrong. Check the CloudWatch log stream — katalonc will print the specific error.
- Common causes: bad `-projectPath`, wrong `-testSuitePath`, invalid API key.

**`aws ecs wait tasks-stopped` times out**
- The default AWS CLI waiter polls for 10 minutes (100 attempts × 6 s). If your test suite takes longer, increase the pipeline `timeout` option and consider implementing a custom polling loop.

**Task never starts (`PROVISIONING` stays forever)**
- The subnet has no route to the internet (NAT gateway or IGW). Either set `ASSIGN_PUBLIC_IP=ENABLED` or add a NAT gateway to the private subnet.
- The security group is blocking ECR image pulls (port 443 outbound required).

**Katalon results not appearing in TestOps**
- Confirm `KATALON_ORG_ID` in the Jenkinsfile matches your Katalon organisation.
- Confirm the API key credential in Jenkins is correct and not expired.
