variable "region" {}
variable "aws_profile" {}

variable "panos_version" {}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair"
}

variable "fw_prefix" {}
variable "fw_vpc_cidr" {}
variable "fw_size" {}

variable "fw_cidr_gwlbe_az1" {}
variable "fw_cidr_gwlbe_az2" {}
variable "fw_cidr_gwlbe_az3" {}
variable "fw_cidr_tgw_az1" {}
variable "fw_cidr_tgw_az2" {}
variable "fw_cidr_tgw_az3" {}
variable "fw_cidr_natgw_az1" {}
variable "fw_cidr_natgw_az2" {}
variable "fw_cidr_natgw_az3" {}

variable "spoke1_prefix" {}
variable "spoke1_vpc_cidr" {}
variable "spoke1_cidr_vm_az1" {}
variable "spoke1_cidr_vm_az2" {}
variable "spoke1_cidr_alb_az1" {}
variable "spoke1_cidr_alb_az2" {}
variable "spoke1_cidr_gwlbe_az1" {}
variable "spoke1_cidr_gwlbe_az2" {}
variable "spoke1_vm1_ip" {}
variable "spoke1_vm2_ip" {}

variable "spoke2_prefix" {}
variable "spoke2_vpc_cidr" {}
variable "spoke2_subnet_cidr" {}
variable "spoke2_vm1_ip" {}
variable "spoke_size" {}

variable "spoke1_acm_arn" { default = "none" }

variable "panorama1" {}
variable "panorama2" {}

variable "panorama_auth_key" {}
variable "panorama_template_stack" {}
variable "panorama_device_group" {}
variable "pan_csp_auto_reg_pin_id" {}
variable "pan_csp_auto_reg_pin_value" {}

variable "decrypt_inbound" { default = "false" }

variable "prefix" {
  type = string
  default = "PANW-GWLB"
}

variable "cloudwatch_namespace" {}
variable "cloudwatch_metricname" {}
variable "cloudwatch_threshold_low_alarm" { default = ""}
variable "cloudwatch_threshold_high_alarm" { default = ""}
variable "cloudwatch_statistic" {
  type = string
}
variable "cloudwatch_target_value" { default = "" }

variable "aws_secret_name_vmseries_asg" {
  sensitive = true
}

variable "aws_secret_name_panorama" {
  sensitive = true
}

variable "panorama_api_key" {
  sensitive = true
}

variable "asg_min" {}
variable "asg_max" {}
variable "asg_desired" {}
variable "collector_group_name" {}

variable "private_routes" {
  type = list(string)
  default = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
}

