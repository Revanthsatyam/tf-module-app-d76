locals {
  name_prefix = "${var.app_name}-${var.env}"
  tags        = merge(var.tags, { Name = "tf-module-app" }, { env = var.env })
}