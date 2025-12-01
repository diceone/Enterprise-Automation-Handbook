data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  instance_name = "${var.project_name}-${var.environment}"
  
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
    }
  )
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr              = var.vpc_cidr
  project_name         = var.project_name
  environment          = var.environment
  availability_zones   = ["us-east-1a", "us-east-1b"]
}

# Security Group
resource "aws_security_group" "app" {
  name        = "${local.instance_name}-sg"
  description = "Security group for ${local.instance_name}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict in production!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-sg"
  })
}

# EC2 Instances
resource "aws_instance" "app" {
  count                = var.instance_count
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = module.vpc.subnet_ids[count.index % length(module.vpc.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.app.id]
  
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  monitoring = var.enable_monitoring

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-${count.index + 1}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Load Balancer
resource "aws_lb" "app" {
  name               = "${local.instance_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = module.vpc.subnet_ids

  enable_deletion_protection = var.environment == "prod"

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-lb"
  })
}

# Target Group
resource "aws_lb_target_group" "app" {
  name        = "${local.instance_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-tg"
  })
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "app" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

# Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
