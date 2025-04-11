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

  ingress {
    description = "Node Exporter for Prometheus"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.prometheus_private_ip
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# resource "aws_security_group_rule" "main" {
#   type              = "ingress"
#   from_port         = 9100
#   to_port           = 9100
#   protocol          = "tcp"
#   cidr_blocks       = var.prometheus_private_ip
#   security_group_id = aws_security_group.main.id
# }

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
          "kms:Decrypt",
          #"kms:GenerateDataKey*",
          "ssm:GetParameterHistory",
          "ssm:GetParametersByPath",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource" : local.policy_resources
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

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    component = var.app_name
    env       = var.env
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 10
      encrypted   = true
      #kms_key_id  = var.kms_key
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${local.name_prefix}" })
  }
}

resource "aws_autoscaling_group" "main" {
  name                = "${local.name_prefix}-asg"
  max_size            = var.max_size
  min_size            = var.min_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_id
  target_group_arns   = [aws_lb_target_group.private.arn]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = local.name_prefix
    propagate_at_launch = true
  }

  tag {
    key                 = "Monitor"
    value               = "yes"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "main" {
  autoscaling_group_name    = aws_autoscaling_group.main.name
  name                      = "CPULoadDetect"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}

resource "aws_route53_record" "main" {
  zone_id = var.zone_id
  name    = var.app_name == "frontend" ? var.env : local.name_prefix
  type    = "CNAME"
  ttl     = 30
  records = [var.app_name == "frontend" ? var.public_dns_record : var.private_dns_record]
}

resource "aws_lb_target_group" "private" {
  name                 = "${local.name_prefix}-alb-tg"
  port                 = var.sg_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 15

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 5
    matcher             = "200"
    path                = "/health"
    port                = var.sg_port
    timeout             = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "private" {
  listener_arn = var.private_listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private.arn
  }

  condition {
    host_header {
      values = [var.app_name == "frontend" ? "${var.env}.rsdevops.in" : "${local.name_prefix}.rsdevops.in"]
    }
  }
}

resource "aws_lb_target_group" "public" {
  count                = var.app_name == "frontend" ? 1 : 0
  name                 = "${local.name_prefix}-alb-public-tg"
  port                 = var.sg_port
  target_type          = "ip"
  protocol             = "HTTP"
  vpc_id               = var.default_vpc_id
  deregistration_delay = 15

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 5
    matcher             = "404"
    path                = "/"
    port                = var.sg_port
    timeout             = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "public" {
  count             = var.app_name == "frontend" ? length(var.subnet_id) : 0
  target_group_arn  = aws_lb_target_group.public[0].arn
  target_id         = element(tolist(data.dns_a_record_set.private_alb_name.addrs), count.index)
  port              = var.sg_port
  availability_zone = "all"
}

resource "aws_lb_listener_rule" "public" {
  count        = var.app_name == "frontend" ? 1 : 0
  listener_arn = var.public_listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public[0].arn
  }

  condition {
    host_header {
      values = [var.env == "prod" ? "www.rsdevops.in" : "${var.env}.rsdevops.in"]
    }
  }
}