variable "ami_id" {}

variable "license_type_map" {
  type = map(string)

  default = {
    "byol"    = "6njl1pau431dv1qxipg63mvah"
    "bundle1" = "e9yfvyj3uag5uo5j2hjikv74n"
    "bundle2" = "hd44w1chf26uv4p52cdynb2o"
  }
}

variable "license" {
}

variable "panos" {
}

variable "size" {
}

variable "eni0_sg_prefix" {
  type = list(string)
}


variable "key_name" {
}

variable "vpc_id" {
}


# variable "s3_bucket" {
#   default = ""
# }

variable "vm_count" {
  default = 1
}

variable "dependencies" {
  type    = list(string)
  default = []
}

variable "eni0_subnet" {
}

variable "eni1_subnet" {
}

variable "eni2_subnet" {
  default = null
}

variable "eni0_public_ip" {
  type    = bool
  default = false
}

variable "eni1_public_ip" {
  type    = bool
  default = false
}

variable "eni2_public_ip" {
  type    = bool
  default = false
}

variable "instance_profile" {
  default = null
}

variable "name" {
  default = "vmseries"
}

variable "user_data" {
  default = ""
}
