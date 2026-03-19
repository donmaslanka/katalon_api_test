output "instance_id" {
  description = "Jenkins instance ID"
  value       = aws_instance.jenkins.id
}

output "instance_arn" {
  description = "Jenkins instance ARN"
  value       = aws_instance.jenkins.arn
}

output "private_ip" {
  description = "Jenkins instance private IP address"
  value       = aws_instance.jenkins.private_ip
}

output "public_ip" {
  description = "Jenkins instance public IP address (if allocated)"
  value       = aws_instance.jenkins.public_ip
}

output "elastic_ip" {
  description = "Elastic IP address (if allocated)"
  value       = var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : null
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = var.allocate_elastic_ip ? "http://${aws_eip.jenkins[0].public_ip}:8080" : "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_dns_name" {
  description = "Jenkins DNS name (if created)"
  value       = var.create_dns_record ? aws_route53_record.jenkins[0].fqdn : null
}

output "security_group_id" {
  description = "Security group ID for Jenkins"
  value       = aws_security_group.jenkins.id
}

output "ami_id" {
  description = "AMI ID used for Jenkins instance"
  value       = aws_instance.jenkins.ami
}

output "instance_type" {
  description = "Instance type of Jenkins server"
  value       = aws_instance.jenkins.instance_type
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}"
}

output "jenkins_cidr" {
  description = "Jenkins server IP in CIDR format (for security group rules)"
  value       = "${aws_instance.jenkins.private_ip}/32"
}
