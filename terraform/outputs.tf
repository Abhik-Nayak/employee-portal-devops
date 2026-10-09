output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "control_node_cidr" {
  description = "Control node IP allowed for SSH"
  value       = local.control_node_cidr
}

output "app_server_instance_ids" {
  description = "Instance IDs of the application servers"
  value       = aws_instance.app[*].id
}

output "app_server_public_ips" {
  description = "Public IPs of the application servers"
  value       = aws_instance.app[*].public_ip
}

output "app_server_private_ips" {
  description = "Private IPs of the application servers"
  value       = aws_instance.app[*].private_ip
}

output "db_server_instance_id" {
  description = "Instance ID of the database server"
  value       = aws_instance.db.id
}

output "db_server_public_ip" {
  description = "Public IP of the database server (SSH from control node only)"
  value       = aws_instance.db.public_ip
}

output "db_server_private_ip" {
  description = "Private IP of the database server (used by the app to reach PostgreSQL)"
  value       = aws_instance.db.private_ip
}

output "app_urls" {
  description = "Employee Portal URLs"
  value       = [for ip in aws_instance.app[*].public_ip : "http://${ip}"]
}
