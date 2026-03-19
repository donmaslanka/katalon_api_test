FROM katalonstudio/katalon:latest

USER root
RUN mkdir -p /katalon/project
WORKDIR /katalon/project

# Copy your Katalon project into the image
COPY . /katalon/project

# Optional sanity check
RUN ls -la /katalon/project

# Katalon CLI entrypoint
ENTRYPOINT ["katalonc"]