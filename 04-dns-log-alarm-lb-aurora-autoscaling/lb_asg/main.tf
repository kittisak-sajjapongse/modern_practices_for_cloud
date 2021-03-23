resource "aws_launch_configuration" "launch-configuration" {
  name                 = var.service-name
  image_id             = var.ami-id
  instance_type        = var.instance-type
  user_data            = var.user-data
  iam_instance_profile = var.iam-instance-profile
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                 = var.service-name
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  desired_capacity     = 3
  max_size             = 10
  min_size             = 2
  launch_configuration = aws_launch_configuration.launch-configuration.name
  target_group_arns    = [aws_lb_target_group.target-group.arn]

   tags = [
       {
            key                 = "Name"
            value               = var.service-name
            propagate_at_launch = true
       }
   ]
}

data "aws_vpc" "default-vpc" {
  default = true
}

data "aws_subnet" "subnet-a" {
  vpc_id            = replace(data.aws_vpc.default-vpc.arn, "/^.*//", "")
  availability_zone = "us-east-1a"
  default_for_az    = true
}

data "aws_subnet" "subnet-b" {
  vpc_id            = replace(data.aws_vpc.default-vpc.arn, "/^.*//", "")
  availability_zone = "us-east-1b"
  default_for_az    = true
}

data "aws_subnet" "subnet-c" {
  vpc_id            = replace(data.aws_vpc.default-vpc.arn, "/^.*//", "")
  availability_zone = "us-east-1c"
  default_for_az    = true
}

resource "aws_lb" "lb" {
  name               = var.service-name
  internal           = false
  load_balancer_type = "application"
  subnets            = [
      replace(data.aws_subnet.subnet-a.arn, "/^.*//", ""),
      replace(data.aws_subnet.subnet-b.arn, "/^.*//", ""),
      replace(data.aws_subnet.subnet-c.arn, "/^.*//", ""),
      ]

  enable_deletion_protection = false

  tags = {
    Name = var.service-name
  }
}

resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.arn
  }
}

resource "aws_lb_target_group" "target-group" {
  name        = var.service-name
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = replace(data.aws_vpc.default-vpc.arn, "/^.*//", "")
}