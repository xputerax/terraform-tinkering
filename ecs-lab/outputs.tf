output "nat_ips" {
  value = [
    aws_eip.private-subnet-1-natgw-eip.public_ip,
    aws_eip.private-subnet-2-natgw-eip.public_ip,
  ]
  description = "NAT Gateway Outbound IP"
  type        = list(string)
}

output "bastion_private_ip" {
  value       = aws_instance.bastion.private_ip
  description = "Bastion Host Private IP"
  type        = string
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "Bastion Host Instance ID"
  type        = string
}

output "lb_url" {
  value       = aws_lb.this.dns_name
  description = "Load Balancer DNS Name"
  type        = string
}

output "node_launchtemplate_version" {
  value       = aws_launch_template.ecs-node-lt.default_version
  description = "Default version for ECS Node Launch Template"
  type        = number
}

output "task_definition_version" {
  value = aws_ecs_task_definition.echo-server.revision
  type  = number
}