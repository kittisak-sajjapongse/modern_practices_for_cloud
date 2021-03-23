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
      name = var.service-name
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
  iam_instance_profile        = aws_iam_instance_profile.wordpress-instance-profile.name
  monitoring                  = true

  tags = {
    Name = var.service-name
  }
}

##### Logging for the Wordpress server #####
# The EC2 instance needs to be attached with an instance profile.
# The instance profile includes the permission to (1) create log streams,
# (2) put log events, and others

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
# We monitor for CPU utilization in this case. If the CPU utilization is higher than 40%,
# the CloudWatch Alarm triggers and sends notitifcation to the SNS for sennding a SMS message
# to a specified phone number.

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
        InstanceId = aws_instance.wordpress.id
  }
}

##### Static Public IP and DNS #####
# This section of the Terraform code creates a hosted zone for a regitered domain name and
# a record of sub-domain for the hosted zone. You will need a valid domain name that you
# own in order to manipulate the domain name.

resource "aws_eip" "wordpress-eip" {
  instance = aws_instance.wordpress.id
}


resource "aws_route53_zone" "wordpress-r53-zone" {
  name = var.domain-name
}

resource "aws_route53_record" "wordpress-dns" {
  zone_id = aws_route53_zone.wordpress-r53-zone.zone_id
  name    = "${var.subdomain}.${var.domain-name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.wordpress-eip.public_ip]
}
