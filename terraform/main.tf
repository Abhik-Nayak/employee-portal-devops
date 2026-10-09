# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------

# Public IP of the control node (Terraform runs on it) - used to restrict SSH
data "http" "control_node_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  control_node_cidr = "${trimspace(data.http.control_node_ip.response_body)}/32"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Ubuntu 22.04 LTS AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# Networking: VPC, public subnet, internet gateway, route table
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

# Application servers: HTTP from anywhere (Nginx), SSH only from the control node
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Application servers - HTTP from internet, SSH from control node"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP (Nginx)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from control node"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.control_node_cidr]
  }

  egress {
    description = "All outbound (package installs, Docker Hub, PostgreSQL)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

# Database server: PostgreSQL only from the app servers, SSH only from the control node
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Database server - PostgreSQL from app servers, SSH from control node"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from application servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description = "SSH from control node"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.control_node_cidr]
  }

  egress {
    description = "All outbound (package installs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}

# ---------------------------------------------------------------------------
# SSH key pair (control node's public key -> passwordless SSH)
# ---------------------------------------------------------------------------

resource "aws_key_pair" "control_node" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.public_key_path))
}

# ---------------------------------------------------------------------------
# EC2 instances: 2 application servers + 1 database server
# ---------------------------------------------------------------------------

resource "aws_instance" "app" {
  count                  = var.app_server_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.control_node.key_name

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-app-${count.index + 1}"
    Role = "app"
  }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.control_node.key_name

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-db"
    Role = "db"
  }
}

# ---------------------------------------------------------------------------
# Generate the Ansible inventory from the created servers
# ---------------------------------------------------------------------------

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tpl", {
    app_servers      = [for s in aws_instance.app : { public_ip = s.public_ip, private_ip = s.private_ip }]
    db_server        = { public_ip = aws_instance.db.public_ip, private_ip = aws_instance.db.private_ip }
    private_key_path = var.private_key_path
  })
}
