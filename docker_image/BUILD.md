# Building & Publishing Katalon Jenkins ECS Agent Image

This image:

- Uses `katalonstudio/katalon:10-latest-slim` as base
- Installs: `git`, `openssh-client`, `xvfb`, `curl`, `unzip`, AWS CLI v2
- Includes `jenkins-agent.sh` as the container ENTRYPOINT, which:
  - Validates `JENKINS_URL`, `JENKINS_SECRET`, `JENKINS_AGENT_NAME`
  - Downloads `agent.jar` from `$JENKINS_URL/jnlpJars/agent.jar` if missing
  - Starts the Jenkins agent in webSocket or JNLP mode

## 1. Build

```bash
docker build -t katalon-docker:latest .
```

## 2. Configure AWS env vars

```bash
export REGION=us-east-2
export ACCOUNT_ID=318798562215
export REPO=katalon-docker
export ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO"
```

## 3. Create ECR Repository (or let Terraform create it)

```bash
aws ecr create-repository --repository-name "$REPO" --region "$REGION" || true
```

## 4. Authenticate Docker to ECR

```bash
aws ecr get-login-password --region "$REGION"  | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
```

## 5. Tag & Push

```bash
docker tag katalon-docker:latest "$ECR_URI:latest"
docker push "$ECR_URI:latest"
```

In the Jenkins ECS Cloud agent template, use:

- **Image**: `$ECR_URI:latest`
- **Label**: `kre`

The ECS plugin will inject the Jenkins env vars and the container will start
as an inbound agent using `jenkins-agent.sh`.
