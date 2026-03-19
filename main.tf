terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "katalon-ecs/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security-groups"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  jenkins_server_ip = var.jenkins_server_ip
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  ecs_task_security_group_id  = module.security_groups.ecs_task_security_group_id
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn
  katalon_image               = var.katalon_image
  katalon_cpu                 = var.katalon_cpu
  katalon_memory              = var.katalon_memory
}

# Jenkins Module (optional - set create_jenkins_server = true to enable)
module "jenkins" {
  count  = var.create_jenkins_server ? 1 : 0
  source = "./modules/jenkins"

  project_name                  = var.project_name
  environment                   = var.environment
  vpc_id                        = module.vpc.vpc_id
  subnet_id                     = module.vpc.public_subnet_ids[0]
  jenkins_ami_id                = var.jenkins_ami_id
  jenkins_ami_name_filter       = var.jenkins_ami_name_filter
  instance_type                 = var.jenkins_instance_type
  key_name                      = var.jenkins_key_name
  jenkins_instance_profile_name = module.iam.jenkins_instance_profile_name
  ssh_allowed_cidrs             = var.jenkins_ssh_allowed_cidrs
  jenkins_web_allowed_cidrs     = var.jenkins_web_allowed_cidrs
  allocate_elastic_ip           = var.jenkins_allocate_elastic_ip
  root_volume_size              = var.jenkins_root_volume_size
  create_data_volume            = var.jenkins_create_data_volume
  data_volume_size              = var.jenkins_data_volume_size
  enable_cloudwatch_logs        = var.jenkins_enable_cloudwatch_logs
  enable_cloudwatch_alarms      = var.jenkins_enable_cloudwatch_alarms

  # ECS Integration
  ecs_cluster_name       = module.ecs.cluster_name
  task_definition_family = module.ecs.katalon_task_definition_family
  aws_region             = var.aws_region
  s3_results_bucket      = module.ecs.s3_results_bucket_name
}
