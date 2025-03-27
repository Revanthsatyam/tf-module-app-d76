resource "aws_security_group" "main" {
  name   = "${local.name_prefix}-sg"
  vpc_id = var.vpc_id
  tags   = merge(local.tags, { Name = "${local.name_prefix}-sg" })

  ingress {
    description = "APP"
    from_port   = var.sg_port
    to_port     = var.sg_port
    protocol    = "tcp"
    cidr_blocks = var.sg_ingress_cidr
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_ingress_cidr
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_iam_role" "main" {
  name               = "${local.name_prefix}-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(local.tags, { Name = "${local.name_prefix}-role" })
}

resource "aws_iam_policy" "main" {
  name        = "${local.name_prefix}-policy"
  description = "${local.name_prefix}-policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameterHistory",
          "ssm:GetParametersByPath",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.main.arn
}

resource "aws_iam_instance_profile" "main" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.main.name
}

resource "aws_launch_template" "main" {
  name                   = "${local.name_prefix}-launch-template"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.main.name
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${local.name_prefix}-launch-template" })
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    component = var.app_name
    env       = var.env
  }))
}

# resource "aws_autoscaling_group" "bar" {
#   name               = "${local.name_prefix}-asg"
#   #availability_zones = ["us-east-1a"]
#   max_size           = var.max_size
#   min_size           = var.min_size
#   desired_capacity   = var.desired_capacity
#
#   launch_template {
#     id      = aws_launch_template.main.id
#     version = "$Latest"
#   }
#
#   tag {
#     key                 = "foo"
#     value               = "bar"
#     propagate_at_launch = true
#   }
# }