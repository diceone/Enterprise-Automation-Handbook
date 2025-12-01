output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "subnet_ids" {
  value       = module.vpc.subnet_ids
  description = "Subnet IDs"
}

output "instance_ids" {
  value       = aws_instance.app[*].id
  description = "EC2 instance IDs"
}

output "instance_public_ips" {
  value       = aws_instance.app[*].public_ip
  description = "EC2 instance public IPs"
}

output "security_group_id" {
  value       = aws_security_group.app.id
  description = "Security group ID"
}

output "load_balancer_dns" {
  value       = aws_lb.app.dns_name
  description = "Load balancer DNS name"
}
