
resource "null_resource" "dependency_getter" {
  provisioner "local-exec" {
    command = "echo ${length(var.dependencies)}"
  }
}

data "aws_ami" "main" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "owner-alias"
    values = ["aws-marketplace"]
  }

  filter {
    name = "product-code"
    values = [var.license_type_map[var.license]]
  }

  filter {
    name   = "name"
    values = ["PA-VM-AWS-${var.panos}*"]
  }
}

resource "aws_security_group" "mgmt" {
  vpc_id      = var.vpc_id
  description = "VM-Series Management SG"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = [ "10.0.0.0/8" ]
  }


  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-mgmt-sg"
  }
}

resource "aws_security_group" "data" {
  vpc_id      = var.vpc_id
  description = "VM-Series Dataplane SG"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-data-sg"
  }
}

resource "aws_network_interface" "eni0" {
  count             = var.vm_count
  subnet_id         = var.eni0_subnet
  security_groups   = [aws_security_group.data.id]
  source_dest_check = true

  tags = {
    Name = "${var.name}-eni0"
  }
}

resource "aws_network_interface" "eni1" {
  count             = var.vm_count
  subnet_id         = var.eni1_subnet
  security_groups   = [aws_security_group.mgmt.id]
  source_dest_check = true

  tags = {
    Name = "${var.name}-eni1"
  }
}

resource "aws_eip" "eni0_pip" {
  count             = var.eni0_public_ip ? var.vm_count : 0
  vpc               = true
  network_interface = element(aws_network_interface.eni0.*.id, count.index)

  tags = {
    Name = "${var.name}-eni0-eip"
  }
}

resource "aws_eip" "eni1_pip" {
  count             = var.eni1_public_ip ? var.vm_count : 0
  vpc               = true
  network_interface = element(aws_network_interface.eni1.*.id, count.index)

  tags = {
    Name = "${var.name}-eni1-eip"
  }
}

/*
resource "aws_eip" "eni2_pip" {
  count             = var.eni2_public_ip ? var.vm_count : 0
  vpc               = true
  network_interface = element(aws_network_interface.eni2.*.id, count.index)

  tags = {
    Name = "${var.name}-eni2-eip"
  }
}
*/

resource "aws_instance" "main" {
  count                                = var.vm_count
  disable_api_termination              = false
  instance_initiated_shutdown_behavior = "stop"
  iam_instance_profile                 = var.instance_profile
  user_data = "hostname=${var.name}\n${var.user_data}"
  #user_data = base64encode(join("", ["vmseries-bootstrap-aws-s3bucket=", var.s3_bucket]),)

  ebs_optimized = true
#  ami           = data.aws_ami.main.image_id
  ami           = var.ami_id
  instance_type = var.size
  key_name      = var.key_name

  monitoring = false

  root_block_device {
    delete_on_termination = "true"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.eni0[count.index].id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.eni1[count.index].id
  }
/*
  network_interface {
    device_index         = 2
    network_interface_id = aws_network_interface.eni2[count.index].id
  }
*/
  tags = {
    Name = var.name
  }


#${self.network_interface.1.private_ip}
# ${element(aws_network_interface.eni1.private_ip, count.index)}
  depends_on = [
    aws_eip.eni0_pip,
    aws_eip.eni1_pip,
    aws_network_interface.eni0,
    aws_network_interface.eni1
#    aws_network_interface.eni2
  ]
}
