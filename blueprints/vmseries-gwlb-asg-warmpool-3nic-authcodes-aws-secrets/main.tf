resource "random_id" "deployment_id" {
  byte_length  = 2
  prefix = "${var.prefix}-"

}

data "http" "myip" {
  url = "https://api.ipify.org"
}