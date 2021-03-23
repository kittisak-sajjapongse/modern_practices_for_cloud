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
    vars = {
      name                 = var.service-name
      rds-cluster-endpoint = module.wordpress-db.cluster-endpoint
    }
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

  ingress {
    description = "Incoming SSH"
    from_port   = 3306
    to_port     = 3306
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

##### The below module creates RDS Aurora cluster #####
# Please navigate to the directory ./lb_asg in order to see the further source.
module wordpress-asg {
  source               = "./lb_asg"
  service-name         = var.service-name
  ami-id               = data.aws_ami.ubuntu.id
  instance-type        = "t3.small"
  user-data            = data.template_file.init.rendered
  iam-instance-profile = aws_iam_instance_profile.wordpress-instance-profile.name
}

##### The below module creates RDS Aurora cluster #####
# Please navigate to the directory ./rds_aurora in order to see the further source.
module wordpress-db {
    source             = "./rds_aurora"
    cluster-name       = var.service-name
    db-name            = "wordpress"
    master-username    = "wordpress"
    master-password    = "changeme"
    security-group-ids = [aws_security_group.wordpress.id]
}

##### Logging for the Wordpress server #####
resource "aws_cloudwatch_log_group" "wordpress" {
  name = var.service-name

  tags = {
    Name = var.service-name
  }
}

resource "aws_iam_instance_profile" "wordpress-instance-profile" {
  name = var.service-name
  role = aws_iam_role.wordpress-role.name
}

resource "aws_iam_role_policy_attachment" "wordpress-role-policy-attachment" {
  role       = aws_iam_role.wordpress-role.name
  policy_arn = aws_iam_policy.wordpress-policy.arn
}

resource "aws_iam_role" "wordpress-role" {
  name = var.service-name
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy" "wordpress-policy" {
  name = var.service-name
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
    ],
      "Resource": [
        "*"
    ]
  }
 ]
}
EOF
}

##### Health Monitoring #####
resource "aws_sns_topic" "wordpress-alarm-topic" {
  name = var.service-name
}

resource "aws_sns_topic_subscription" "wordpress-alarm-subscription" {
  topic_arn = aws_sns_topic.wordpress-alarm-topic.arn
  protocol  = "sms"
  endpoint  = var.alarm-sms-number
}

resource "aws_cloudwatch_metric_alarm" "wordpress-cpu-alarm" {
  alarm_name                = var.service-name
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "40"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []
  treat_missing_data        = "breaching"
  alarm_actions             = [aws_sns_topic.wordpress-alarm-topic.arn]

  namespace                 = "AWS/EC2"
  metric_name               = "CPUUtilization"

  dimensions = {
        AutoScalingGroupName = var.service-name
  }
}
