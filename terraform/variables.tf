variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used for resource names and tags"
  type        = string
  default     = "employee-portal"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_instance_type" {
  description = "EC2 instance type for the application servers"
  type        = string
  default     = "t2.micro"
}

variable "db_instance_type" {
  description = "EC2 instance type for the database server"
  type        = string
  default     = "t2.micro"
}

variable "app_server_count" {
  description = "Number of application servers"
  type        = number
  default     = 2
}

variable "public_key_path" {
  description = "Public key of the control node, installed on all servers for passwordless SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Matching private key on the control node (written into the Ansible inventory)"
  type        = string
  default     = "~/.ssh/id_rsa"
}
