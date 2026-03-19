#!/bin/bash

# Script to install AWS CLI, Jenkins, jq and prerequisites on CentOS Stream 8
# Run with sudo privileges

set -e  # Exit on any error

echo "=========================================="
echo "Starting installation on CentOS Stream 8"
echo "=========================================="

# Update system packages
echo "Updating system packages..."
sudo dnf update -y

# Install prerequisites
echo "Installing prerequisites..."
sudo dnf install -y wget curl unzip java-11-openjdk java-11-openjdk-devel git

# Set JAVA_HOME
echo "Setting JAVA_HOME..."
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" | sudo tee -a /etc/profile.d/java.sh
source /etc/profile.d/java.sh

# Install jq
echo "Installing jq..."
sudo dnf install -y jq
echo "jq version: $(jq --version)"

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
echo "AWS CLI version: $(aws --version)"

# Install Jenkins
echo "Installing Jenkins..."

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo dnf install -y jenkins

# Enable and start Jenkins service
echo "Enabling and starting Jenkins service..."
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Check Jenkins status
sudo systemctl status jenkins --no-pager

# Get initial admin password
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Installed versions:"
echo "- Java: $(java -version 2>&1 | head -n 1)"
echo "- jq: $(jq --version)"
echo "- AWS CLI: $(aws --version)"
echo "- Jenkins: $(rpm -q jenkins)"
echo ""
echo "Jenkins initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "Jenkins is running on: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "Next steps:"
echo "1. Open firewall port 8080 if needed: sudo firewall-cmd --permanent --add-port=8080/tcp && sudo firewall-cmd --reload"
echo "2. Access Jenkins at http://YOUR_SERVER_IP:8080"
echo "3. Use the initial admin password shown above"
echo "4. Configure AWS CLI: aws configure"
echo "=========================================="
