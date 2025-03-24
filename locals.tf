locals {
  name_prefix = "${var.env}-${var.app_name}"
  tags = merge(var.tags, { Name = "tf-module-app" }, { env = var.env })
}