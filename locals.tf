locals {
  name_prefix      = "${var.app_name}-${var.env}"
  parameters       = var.parameters
  policy_resources = concat ([ for i in local.parameters : "arn:aws:ssm:us-east-1:058264090525:parameter/${i}.${var.env}.*" ], [var.kms_key])
  tags             = merge(var.tags, { Name = "tf-module-app" }, { env = var.env })
}