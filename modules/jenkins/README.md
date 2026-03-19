# Jenkins Module

This module creates a Jenkins EC2 instance from an AMI with full integration to the ECS Katalon testing infrastructure.

## Features

- ✅ Launch Jenkins from existing AMI
- ✅ Automatic ECS integration via IAM role
- ✅ Elastic IP for stable access
- ✅ CloudWatch Logs integration
- ✅ CloudWatch Alarms for monitoring
- ✅ Security groups with configurable access
- ✅ Optional data volume for Jenkins data
- ✅ User data script for automatic configuration
- ✅ Optional Route53 DNS record
- ✅ Optional AWS Backup integration

## Usage

### Basic Usage (with existing AMI)

```hcl
module "jenkins" {
  source = "./modules/jenkins"

  project_name  = "katalon-testing"
  environment   = "dev"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  
  # AMI Configuration
  jenkins_ami_id = "ami-0abcdef1234567890"  # Your Jenkins AMI
  
  # Instance Configuration
  instance_type = "t3.medium"
  key_name      = "my-ssh-key"
  
  # IAM Integration
  jenkins_instance_profile_name = module.iam.jenkins_instance_profile_name
  
  # Security
  ssh_allowed_cidrs         = ["203.0.113.0/24"]
  jenkins_web_allowed_cidrs = ["203.0.113.0/24"]
  
  # ECS Integration
  ecs_cluster_name       = module.ecs.cluster_name
  task_definition_family = module.ecs.katalon_task_definition_family
  aws_region             = "us-east-1"
  s3_results_bucket      = module.ecs.s3_results_bucket_name
}
```

### Advanced Usage (with automatic AMI discovery)

```hcl
module "jenkins" {
  source = "./modules/jenkins"

  project_name            = "katalon-testing"
  environment             = "dev"
  vpc_id                  = module.vpc.vpc_id
  subnet_id               = module.vpc.public_subnet_ids[0]
  
  # Automatic AMI discovery
  jenkins_ami_name_filter = "jenkins-prod-*"
  
  # Instance Configuration
  instance_type = "t3.large"
  key_name      = "my-ssh-key"
  
  # Storage
  root_volume_size   = 100
  create_data_volume = true
  data_volume_size   = 200
  
  # Networking
  allocate_elastic_ip       = true
  ssh_allowed_cidrs         = ["10.0.0.0/8"]
  jenkins_web_allowed_cidrs = ["10.0.0.0/8", "172.16.0.0/12"]
  
  # Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_logs     = true
  enable_cloudwatch_alarms   = true
  cpu_alarm_threshold        = 80
  
  # DNS
  create_dns_record = true
  route53_zone_id   = "Z1234567890ABC"
  jenkins_hostname  = "jenkins.example.com"
  
  # IAM and ECS Integration
  jenkins_instance_profile_name = module.iam.jenkins_instance_profile_name
  ecs_cluster_name              = module.ecs.cluster_name
  task_definition_family        = module.ecs.katalon_task_definition_family
  aws_region                    = "us-east-1"
  s3_results_bucket             = module.ecs.s3_results_bucket_name
}
```

## Root Module Integration

In your root `main.tf`:

```hcl
module "jenkins" {
  count  = var.create_jenkins_server ? 1 : 0
  source = "./modules/jenkins"

  project_name                 = var.project_name
  environment                  = var.environment
  vpc_id                       = module.vpc.vpc_id
  subnet_id                    = module.vpc.public_subnet_ids[0]
  jenkins_ami_id               = var.jenkins_ami_id
  instance_type                = var.jenkins_instance_type
  key_name                     = var.jenkins_key_name
  jenkins_instance_profile_name = module.iam.jenkins_instance_profile_name
  ssh_allowed_cidrs            = var.jenkins_ssh_allowed_cidrs
  jenkins_web_allowed_cidrs    = var.jenkins_web_allowed_cidrs
  
  # ECS Integration
  ecs_cluster_name       = module.ecs.cluster_name
  task_definition_family = module.ecs.katalon_task_definition_family
  aws_region             = var.aws_region
  s3_results_bucket      = module.ecs.s3_results_bucket_name
}
```

In your `terraform.tfvars`:

```hcl
# Enable Jenkins creation
create_jenkins_server = true

# Jenkins AMI (your client's Jenkins image)
jenkins_ami_id = "ami-0abcdef1234567890"

# Instance configuration
jenkins_instance_type = "t3.medium"
jenkins_key_name      = "my-keypair"

# Security (IMPORTANT: Restrict these!)
jenkins_ssh_allowed_cidrs = ["203.0.113.0/24"]
jenkins_web_allowed_cidrs = ["203.0.113.0/24"]
```

## User Data Script

The module includes an automatic configuration script that:

1. **Updates system packages**
2. **Installs/configures AWS CLI**
3. **Sets up environment variables** for ECS integration
4. **Configures CloudWatch Logs agent**
5. **Verifies ECS and S3 access**
6. **Creates helper scripts** for running Katalon tests

The user data script configures:
- `/etc/jenkins/ecs-config.env` - Environment variables
- `/usr/local/bin/run-katalon-test` - Helper script

### Helper Script Usage

Once Jenkins is running, you can use the helper script:

```bash
# SSH into Jenkins
ssh -i my-key.pem ec2-user@<jenkins-ip>

# Run a test
sudo run-katalon-test smoke-tests https://example.com
```

## Security Considerations

### Network Security

**IMPORTANT**: Always restrict access in production!

```hcl
# Good - Restricted access
ssh_allowed_cidrs         = ["203.0.113.0/24"]  # Your office IP
jenkins_web_allowed_cidrs = ["203.0.113.0/24"]  # Your office IP

# Bad - Open to internet
ssh_allowed_cidrs         = ["0.0.0.0/0"]
jenkins_web_allowed_cidrs = ["0.0.0.0/0"]
```

### Best Practices

1. **Use Elastic IP** - Provides stable access point
2. **Restrict CIDR blocks** - Limit to known IPs/VPNs
3. **Enable CloudWatch Logs** - For audit and troubleshooting
4. **Enable CloudWatch Alarms** - Get notified of issues
5. **Use data volume** - Separate Jenkins data from OS
6. **Enable backups** - Use AWS Backup for disaster recovery
7. **Use IMDSv2** - Automatically configured for security

## Monitoring

### CloudWatch Logs

Jenkins logs are automatically sent to CloudWatch:

```bash
# View logs
aws logs tail /aws/ec2/<project>-<env>-jenkins --follow

# Specific log stream
aws logs get-log-events \
  --log-group-name /aws/ec2/<project>-<env>-jenkins \
  --log-stream-name <instance-id>/jenkins.log
```

### CloudWatch Alarms

Two alarms are created by default:

1. **High CPU Utilization** - Triggers at 80% (configurable)
2. **Status Check Failed** - Triggers on instance health issues

### Metrics to Monitor

- CPU Utilization
- Memory Utilization (requires CloudWatch agent)
- Disk Usage
- Network In/Out
- Status Check Failed

## Storage Options

### Root Volume Only (Default)

```hcl
root_volume_size   = 50
create_data_volume = false
```

### With Dedicated Data Volume

```hcl
root_volume_size   = 50
create_data_volume = true
data_volume_size   = 200
```

The data volume is mounted at `/dev/sdf` and must be manually mounted:

```bash
# SSH into instance
sudo mkfs -t ext4 /dev/sdf
sudo mkdir /jenkins-data
sudo mount /dev/sdf /jenkins-data
sudo chown jenkins:jenkins /jenkins-data

# Add to fstab for persistence
echo '/dev/sdf /jenkins-data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

## DNS Configuration

### Route53 Integration

```hcl
create_dns_record = true
route53_zone_id   = "Z1234567890ABC"
jenkins_hostname  = "jenkins.example.com"
```

Access Jenkins via: `http://jenkins.example.com:8080`

## Backup Configuration

### AWS Backup Integration

```hcl
enable_backup        = true
backup_plan_id       = aws_backup_plan.daily.id
backup_iam_role_arn  = aws_iam_role.backup.arn
```

This automatically includes the Jenkins instance in your backup plan.

## Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | Jenkins EC2 instance ID |
| `instance_arn` | Jenkins instance ARN |
| `private_ip` | Private IP address |
| `public_ip` | Public IP address (if allocated) |
| `elastic_ip` | Elastic IP address (if allocated) |
| `jenkins_url` | Full Jenkins URL |
| `jenkins_dns_name` | DNS name (if created) |
| `security_group_id` | Security group ID |
| `ssh_command` | Ready-to-use SSH command |
| `jenkins_cidr` | Jenkins IP in CIDR format (for security group rules) |

## Troubleshooting

### Jenkins won't start

```bash
# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs
sudo tail -f /var/log/jenkins/jenkins.log

# Check user data script
sudo cat /var/log/user-data.log
```

### Can't access ECS

```bash
# Verify IAM role
aws sts get-caller-identity

# Test ECS access
aws ecs describe-clusters --clusters <cluster-name>

# Check instance profile
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

### Network connectivity issues

```bash
# Check security group
aws ec2 describe-security-groups --group-ids <sg-id>

# Verify route table
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"

# Test internet access
curl -I https://google.com
```

### CloudWatch Logs not appearing

```bash
# Check CloudWatch agent status
sudo amazon-cloudwatch-agent-ctl -a query -m ec2 -c default -s

# Restart agent
sudo amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Check IAM permissions
aws logs describe-log-groups
```

## Cost Estimation

### t3.medium Instance
- Instance: ~$30/month (on-demand)
- EBS (50GB gp3): ~$4/month
- Elastic IP: $0 (when attached)
- Data transfer: Variable
- CloudWatch Logs: ~$0.50/GB
- **Total: ~$35-40/month**

### t3.large Instance
- Instance: ~$60/month (on-demand)
- EBS (100GB gp3): ~$8/month
- Data volume (200GB): ~$16/month
- **Total: ~$85-90/month**

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Resources Created

- `aws_instance.jenkins` - Jenkins EC2 instance
- `aws_security_group.jenkins` - Security group
- `aws_eip.jenkins` - Elastic IP (optional)
- `aws_eip_association.jenkins` - EIP association (optional)
- `aws_cloudwatch_log_group.jenkins` - Log group (optional)
- `aws_cloudwatch_metric_alarm.jenkins_cpu` - CPU alarm (optional)
- `aws_cloudwatch_metric_alarm.jenkins_status_check` - Status alarm (optional)
- `aws_route53_record.jenkins` - DNS record (optional)
- `aws_backup_selection.jenkins` - Backup selection (optional)

## Example: Complete Configuration

```hcl
module "jenkins" {
  source = "./modules/jenkins"

  # Basic Configuration
  project_name  = "katalon-testing"
  environment   = "production"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnet_ids[0]
  
  # AMI
  jenkins_ami_id = "ami-0abcdef1234567890"
  
  # Instance
  instance_type = "t3.large"
  key_name      = "production-key"
  
  # Storage
  root_volume_type   = "gp3"
  root_volume_size   = 100
  create_data_volume = true
  data_volume_type   = "gp3"
  data_volume_size   = 500
  
  # Network Security
  associate_public_ip       = true
  allocate_elastic_ip       = true
  ssh_allowed_cidrs         = ["203.0.113.0/24"]
  jenkins_web_allowed_cidrs = ["203.0.113.0/24"]
  
  # Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_logs     = true
  log_retention_days         = 30
  enable_cloudwatch_alarms   = true
  cpu_alarm_threshold        = 75
  alarm_sns_topic_arn        = aws_sns_topic.alerts.arn
  
  # DNS
  create_dns_record = true
  route53_zone_id   = data.aws_route53_zone.main.zone_id
  jenkins_hostname  = "jenkins.company.com"
  
  # Backup
  enable_backup        = true
  backup_plan_id       = aws_backup_plan.daily.id
  backup_iam_role_arn  = aws_iam_role.backup.arn
  
  # IAM
  jenkins_instance_profile_name = module.iam.jenkins_instance_profile_name
  
  # ECS Integration
  ecs_cluster_name       = module.ecs.cluster_name
  task_definition_family = module.ecs.katalon_task_definition_family
  aws_region             = "us-east-1"
  s3_results_bucket      = module.ecs.s3_results_bucket_name
}
```

## Migration from Existing Jenkins

If you have an existing Jenkins server and want to migrate:

1. **Create AMI** from existing Jenkins instance
2. **Note the AMI ID**
3. **Set variables** in terraform.tfvars:
   ```hcl
   create_jenkins_server = true
   jenkins_ami_id        = "ami-from-step-1"
   ```
4. **Deploy** with Terraform
5. **Update DNS** to point to new instance
6. **Verify** Jenkins is working
7. **Terminate** old instance

## License

This module is part of the Katalon ECS Terraform project.
