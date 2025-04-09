locals {
  name_prefix      = "${var.app_name}-${var.env}"
  tags             = merge(var.tags, { Name = "tf-module-app" }, { env = var.env })
  parameters       = var.parameters
  policy_resources = [ "arn:aws:ssm:us-east-1:058264090525:parameter/*", var.kms_key ]
}