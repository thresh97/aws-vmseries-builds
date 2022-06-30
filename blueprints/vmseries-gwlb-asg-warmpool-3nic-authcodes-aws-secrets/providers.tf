terraform {
  required_version = ">= 0.14.9"
}

provider aws {
  region  = var.region
  profile = "${var.aws_profile}"
}


# For unique naming, create random string that will be appended to resource names
resource "random_string" "main" {
  length      = 8
  min_numeric = 8
  special     = false
}


data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
