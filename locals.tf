locals {
  name_prefix      = "${var.app_name}-${var.env}"
  tags             = merge(var.tags, { Name = "tf-module-app" }, { env = var.env })
  policy_resources = [ "arn:aws:ssm:us-east-1:058264090525:parameter/*", "arn:aws:kms:us-east-1:058264090525:key/2c990b0f-c40d-4ede-957b-66ec02f92cf3" ]
}