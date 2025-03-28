# data "aws_autoscaling_group" "main" {
#   name = aws_autoscaling_group.main.name
# }

data "dns_a_record_set" "private_alb_name" {
  host = var.private_dns_record
}