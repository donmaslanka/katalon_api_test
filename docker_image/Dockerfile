# ────────────────────────────────────────────────────────────────────────────
# Katalon ECS test runner
#
# This image is pushed to ECR and run on-demand by the Jenkins pipeline via
# `aws ecs run-task`.  It does NOT run a Jenkins agent.
#
# Build & push:
#   IMAGE=318798562215.dkr.ecr.us-west-2.amazonaws.com/katalon-test-runner
#   TAG=<your-tag>
#   aws ecr get-login-password --region us-west-2 \
#     | docker login --username AWS --password-stdin \
#         318798562215.dkr.ecr.us-west-2.amazonaws.com
#   docker build -t $IMAGE:$TAG .
#   docker push $IMAGE:$TAG
#
# Then update katalon_image in terraform.tfvars and re-apply, or register
# a new task definition revision with the updated image URI.
# ────────────────────────────────────────────────────────────────────────────

FROM katalonstudio/katalon:latest

USER root

# Project is baked into the image at build time.
# The Jenkins pipeline passes -projectPath=/katalon/project as a CLI override.
RUN mkdir -p /katalon/project
WORKDIR /katalon/project
COPY . /katalon/project

# Sanity check — surfaces missing files at build time rather than runtime.
RUN ls -la /katalon/project

# katalonc is the Katalon CLI.  The Jenkins pipeline supplies all arguments
# via ECS container command overrides (containerOverrides.command[]).
ENTRYPOINT ["katalonc"]
