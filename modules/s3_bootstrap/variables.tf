variable bucket_name {
}

variable file_location {
}

variable config {
  type    = list(string)
  default = []
}

variable content {
  type    = list(string)
  default = []
}

variable license {
  type    = list(string)
  default = []
}

variable software {
  default = []
}

variable other {
  default = []
}

variable create_instance_profile {
  type    = bool
  default = false
}
