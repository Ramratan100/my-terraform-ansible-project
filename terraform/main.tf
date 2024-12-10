provider "aws" {
  region = "us-east-1"  # Specify the AWS region
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "ramratan-bucket-2510"  # Your bucket name
  acl    = "private"
}

# DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "MySQL-VPC"
  }
}

# Create a Subnet
resource "aws_subnet" "main" {
  vpc_id                 = aws_vpc.main.id
  cidr_block             = "10.0.1.0/24"
  availability_zone      = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "MySQL-Subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MySQL-IGW"
  }
}

# Create Route Table and Route for Internet Access
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MySQL-RouteTable"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Security Group for EC2 Instance
resource "aws_security_group" "mysql_ec2_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "mysql_ec2_sg"
  description = "Security group for MySQL EC2 instance"
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open MySQL port to the world (change this for security)
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open SSH port to the world (be cautious about this)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MySQL-EC2-SG"
  }
}

# Create EC2 Instance
resource "aws_instance" "mysql_instance" {
  ami                    = "ami-005fc0f236362e99f"  # Example AMI, update with the latest Ubuntu AMI ID
  instance_type           = "t2.micro"
  subnet_id               = aws_subnet.main.id
  vpc_security_group_ids  = [aws_security_group.mysql_ec2_sg.id]
  key_name                = "jenkins"  # Ensure this matches your AWS key pair

  tags = {
    Name = "MySQL-EC2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y mysql-server
              systemctl start mysql
              systemctl enable mysql
            EOF
}

# Output EC2 Public IP
output "mysql_instance_public_ip" {
  value = aws_instance.mysql_instance.public_ip
}

