output "eni0" {
  value = aws_network_interface.eni0.*.id
}

output "eni1" {
  value = aws_network_interface.eni1.*.id
}

# output "eni2" {
#   value = aws_network_interface.eni2.*.id
# }

output "instance_id" {
  value = aws_instance.main.*.id
}



output "eni0_public_ip" {
  value = var.eni0_public_ip ? aws_eip.eni0_pip.*.public_ip : []
}

output "eni1_public_ip" {
  value = var.eni1_public_ip ? aws_eip.eni1_pip.*.public_ip : []
}

# output "eni2_public_ip" {
#   value = var.eni2_public_ip ? aws_eip.eni2_pip.*.public_ip : []
# }



output "data_security_group" {
    value = aws_security_group.data.id
}
