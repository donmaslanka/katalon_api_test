# Base image (already Linux amd64 compatible)
FROM katalonstudio/katalon:10-latest-slim

USER root

# ------------------------------------------------------------
# System tools
# ------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    xvfb \
    curl \
    unzip \
    ca-certificates \
    sed && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# AWS CLI (x86_64 – matches Fargate runtime)
# ------------------------------------------------------------
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "/tmp/awscliv2.zip" && \
    unzip /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# ------------------------------------------------------------
# Jenkins agent setup
# ------------------------------------------------------------
RUN mkdir -p /usr/share/jenkins

# Copy the agent script into a canonical location...
COPY jenkins-agent.sh /usr/local/bin/jenkins-agent

# ...and ALSO copy to /jenkins-agent.sh for backward compatibility
# (some task defs / wrappers / older configs expect this exact path)
COPY jenkins-agent.sh /jenkins-agent.sh

# Normalize CRLF -> LF and ensure executable bit on both paths
RUN sed -i 's/\r$//' /usr/local/bin/jenkins-agent /jenkins-agent.sh && \
    chmod 0755 /usr/local/bin/jenkins-agent /jenkins-agent.sh

# ------------------------------------------------------------
# Jenkins agent runtime config
# ------------------------------------------------------------
ENV JENKINS_AGENT_WORKDIR=/workspace

WORKDIR /workspace

# Execute directly so the shebang is honored
ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
