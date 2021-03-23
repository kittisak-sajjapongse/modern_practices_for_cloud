terraform {
    backend "s3" {
    }
}

provider "aws" {
    region  = var.aws-region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "template_file" "init" {
    template = file("user_data.sh")
}

resource "aws_security_group" "wordpress" {
  name        = var.service-name
  description = "Allow HTTP inbound traffic"

  ingress {
    description = "Incoming HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Incoming SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.service-name
  }
}

resource "aws_instance" "wordpress" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  user_data                   = data.template_file.init.rendered
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.wordpress.id]

  tags = {
    Name = var.service-name
  }
}
