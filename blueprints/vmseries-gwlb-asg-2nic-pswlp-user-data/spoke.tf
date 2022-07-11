#-----------------------------------------------------------------------------------------------
# Pull Ubuntu marketplace image
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "web_startup" {
  template = file("${path.module}/scripts/cloud_init_web.yml.tpl")
}

#-----------------------------------------------------------------------------------------------
# Create spoke1 VPC, IGW, & subnets
resource "aws_vpc" "spoke1" {
  cidr_block = var.spoke1_vpc_cidr

  tags = {
    Name = "${random_id.deployment_id.hex}_${var.spoke1_prefix}-vpc"
    IpType = "vpc"
  }
}

resource "aws_internet_gateway" "spoke1" {
  vpc_id = aws_vpc.spoke1.id

  tags = {
    Name = "${var.spoke1_prefix}-igw"
  }
}

module "spoke1_subnets" {
  source             = "../../modules/subnets/"
  vpc_id             = aws_vpc.spoke1.id
  subnet_name_prefix = "${var.spoke1_prefix}-"

  subnets = {
    "vm-az1" = {
      az   = data.aws_availability_zones.available.names[0]
      cidr = var.spoke1_cidr_vm_az1
    },
    "vm-az2" = {
      az   = data.aws_availability_zones.available.names[1]
      cidr = var.spoke1_cidr_vm_az2
    },
    "alb-az1" = {
      az   = data.aws_availability_zones.available.names[0]
      cidr = var.spoke1_cidr_alb_az1
    },
    "alb-az2" = {
      az   = data.aws_availability_zones.available.names[1]
      cidr = var.spoke1_cidr_alb_az2
    },
    "gwlbe-az1" = {
      az   = data.aws_availability_zones.available.names[0]
      cidr = var.spoke1_cidr_gwlbe_az1
    },
    "gwlbe-az2" = {
      az   = data.aws_availability_zones.available.names[1]
      cidr = var.spoke1_cidr_gwlbe_az2
    }

  }
}

#-----------------------------------------------------------------------------------------------
# Create spoke1 GWLBE in both AZs and map to GWLB service (in gwlb.tf)
resource "aws_vpc_endpoint" "spoke1_az1" {
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  subnet_ids        = [module.spoke1_subnets.subnet_ids["gwlbe-az1"]]
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlb.service_type
  vpc_id            = aws_vpc.spoke1.id

  tags = {
    Name = "${var.spoke1_prefix}-endpoint-az1"
  }
}

resource "aws_vpc_endpoint" "spoke1_az2" {
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  subnet_ids        = [module.spoke1_subnets.subnet_ids["gwlbe-az2"]]
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlb.service_type
  vpc_id            = aws_vpc.spoke1.id

  tags = {
    Name = "${var.spoke1_prefix}-endpoint-az2"
  }
}

#-----------------------------------------------------------------------------------------------
# Create spoke1 route tables and associations
resource "aws_route_table" "spoke1_vm" {
  vpc_id = aws_vpc.spoke1.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.spoke1_attachment.transit_gateway_id
  }

  tags = {
    Name = "${var.spoke1_prefix}-vm-rtb"
  }
}

resource "aws_route_table" "spoke1_alb_az1" {
  vpc_id = aws_vpc.spoke1.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.spoke1_az1.id
  }

  tags = {
    Name = "${var.spoke1_prefix}-alb-az1-rtb"
  }
}

resource "aws_route_table" "spoke1_alb_az2" {
  vpc_id = aws_vpc.spoke1.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.spoke1_az2.id
  }

  tags = {
    Name = "${var.spoke1_prefix}-alb-az2-rtb"
  }
}


resource "aws_route_table" "spoke1_gwlbe" {
  vpc_id = aws_vpc.spoke1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spoke1.id
  }

  tags = {
    Name = "${var.spoke1_prefix}-gwlbe-rtb"
  }
}

resource "aws_route_table" "spoke1_igw" {
  vpc_id = aws_vpc.spoke1.id

  route {
    cidr_block      = var.spoke1_cidr_alb_az1
    vpc_endpoint_id = aws_vpc_endpoint.spoke1_az1.id
  }

  route {
    cidr_block      = var.spoke1_cidr_alb_az2
    vpc_endpoint_id = aws_vpc_endpoint.spoke1_az2.id
  }

  tags = {
    Name = "${var.spoke1_prefix}-igw-rtb"
  }
}

resource "aws_route_table_association" "spoke1_vm_az1" {
  subnet_id      = module.spoke1_subnets.subnet_ids["vm-az1"]
  route_table_id = aws_route_table.spoke1_vm.id
}

resource "aws_route_table_association" "spoke1_vm_az2" {
  subnet_id      = module.spoke1_subnets.subnet_ids["vm-az2"]
  route_table_id = aws_route_table.spoke1_vm.id
}

resource "aws_route_table_association" "spoke1_alb_az1" {
  subnet_id      = module.spoke1_subnets.subnet_ids["alb-az1"]
  route_table_id = aws_route_table.spoke1_alb_az1.id
}

resource "aws_route_table_association" "spoke1_alb_az2" {
  subnet_id      = module.spoke1_subnets.subnet_ids["alb-az2"]
  route_table_id = aws_route_table.spoke1_alb_az2.id
}

resource "aws_route_table_association" "spoke1_gwlb_az1" {
  subnet_id      = module.spoke1_subnets.subnet_ids["gwlbe-az1"]
  route_table_id = aws_route_table.spoke1_gwlbe.id
}

resource "aws_route_table_association" "spoke1_gwlb_az2" {
  subnet_id      = module.spoke1_subnets.subnet_ids["gwlbe-az2"]
  route_table_id = aws_route_table.spoke1_gwlbe.id
}

resource "aws_route_table_association" "spoke1_igw" {
  gateway_id     = aws_internet_gateway.spoke1.id
  route_table_id = aws_route_table.spoke1_igw.id
}


#-----------------------------------------------------------------------------------------------
# Create spoke1 security group and EC2 instance
resource "aws_security_group" "spoke1_sg" {
  description = "${var.spoke1_prefix}-sg"
  vpc_id      = aws_vpc.spoke1.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.spoke1_prefix}-sg"
  }

}

resource "aws_network_interface" "spoke1_vm1" {
  subnet_id         = module.spoke1_subnets.subnet_ids["vm-az1"]
  security_groups   = [aws_security_group.spoke1_sg.id]
  private_ips       = [var.spoke1_vm1_ip]

  tags = {
    Name = "${var.spoke1_prefix}-eni0"
  }
}

resource "aws_network_interface" "spoke1_vm2" {
  subnet_id         = module.spoke1_subnets.subnet_ids["vm-az2"]
  security_groups   = [aws_security_group.spoke1_sg.id]
  private_ips       = [var.spoke1_vm2_ip]

  tags = {
    Name = "${var.spoke1_prefix}-eni0"
  }
}

resource "aws_instance" "spoke1_vm1" {
  disable_api_termination = false
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.spoke_size
  key_name                = var.key_name
  user_data               = base64encode(data.template_file.web_startup.rendered)

  root_block_device {
    delete_on_termination = "true"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.spoke1_vm1.id
  }

  tags = {
    Name = "${var.spoke1_prefix}-vm1"
    AllowOutboundInternet = "yes"
  }

}

resource "aws_instance" "spoke1_vm2" {
  disable_api_termination = false
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.spoke_size
  key_name                = var.key_name
  user_data               = base64encode(data.template_file.web_startup.rendered)

  root_block_device {
    delete_on_termination = "true"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.spoke1_vm2.id
  }

  tags = {
    Name = "${var.spoke1_prefix}-vm2"
    AllowOutboundInternet = "yes"
  }

}

resource "aws_lb" "spoke1" {
  name               = "${random_id.deployment_id.hex}-${var.spoke1_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.spoke1_sg.id]

  subnets = [
    module.spoke1_subnets.subnet_ids["alb-az1"],
    module.spoke1_subnets.subnet_ids["alb-az2"]
  ]

}

resource "aws_lb_target_group" "spoke1" {
  name        = "${var.spoke1_prefix}-asg-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.spoke1.id
}

resource "aws_lb_target_group_attachment" "spoke1_vm1" {
  target_group_arn = aws_lb_target_group.spoke1.arn
#  target_id        = var.spoke1_vm1_ip
  target_id = aws_instance.spoke1_vm1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "spoke1_vm2" {
  target_group_arn = aws_lb_target_group.spoke1.arn
#  target_id        = var.spoke1_vm2_ip
  target_id = aws_instance.spoke1_vm2.id
  port             = 80
}

resource "aws_lb_listener" "spoke1" {
  load_balancer_arn = aws_lb.spoke1.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.spoke1.arn
  }
}
output "SPOKE1-ALB" {
  value = "http://${aws_lb.spoke1.dns_name}"
}

#-----------------------------------------------------------------------------------------------
# Create spoke2 VPC & subnets
resource "aws_vpc" "spoke2" {
  cidr_block = var.spoke2_vpc_cidr

  tags = {
    Name = "${random_id.deployment_id.hex}_${var.spoke2_prefix}-vpc"
    IpType = "vpc"
  }
}

resource "aws_internet_gateway" "spoke2" {
  vpc_id = aws_vpc.spoke2.id

  tags = {
    Name = "${var.spoke2_prefix}-igw"
  }
}


resource "aws_subnet" "spoke2" {
  vpc_id            = aws_vpc.spoke2.id
  cidr_block        = var.spoke2_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.spoke2_prefix}-vm-az1"
    IpType = "subnet"
    DecryptOutbound = "true"
  }
}


#-----------------------------------------------------------------------------------------------
# Create spoke2 route table
resource "aws_route_table" "spoke2" {
  vpc_id = aws_vpc.spoke2.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.spoke2_attachment.transit_gateway_id
  }

  route {
    cidr_block = "${data.http.myip.body}/32"
    gateway_id = aws_internet_gateway.spoke2.id
  }

  tags = {
    Name = "${var.spoke2_prefix}-rtb"
  }
}

resource "aws_route_table_association" "spoke2" {
  subnet_id      = aws_subnet.spoke2.id
  route_table_id = aws_route_table.spoke2.id
}


#-----------------------------------------------------------------------------------------------
# Create spoke2 security group and EC2 instance
resource "aws_security_group" "spoke2_sg" {
  vpc_id = aws_vpc.spoke2.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.spoke1_prefix}-sg"
  }
}

resource "aws_network_interface" "spoke2_vm1" {
  subnet_id         = aws_subnet.spoke2.id
  security_groups   = [aws_security_group.spoke2_sg.id]
  private_ips       = [var.spoke2_vm1_ip]

  tags = {
    Name = "${var.spoke2_prefix}-eni0"
  }
}

resource "aws_eip" "spoke2_vm1" {
  vpc                       = true
  network_interface         = aws_network_interface.spoke2_vm1.id

  tags = {
    Name = "${var.spoke2_prefix}-eni0-eip"
  }
}

resource "aws_instance" "spoke2_vm1" {
  disable_api_termination = false
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.spoke_size
  key_name                = var.key_name

  user_data               = base64encode(data.template_file.web_startup.rendered)

  root_block_device {
    delete_on_termination = "true"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.spoke2_vm1.id
  }

  tags = {
    Name = "${var.spoke2_prefix}-vm1"
    AllowOutboundInternet = "no"
  }

  depends_on = [
    aws_eip.spoke2_vm1
  ]
}

output "SPOKE2-SSH-JUMP-ACCESS" {
  value = "ssh ubuntu@${aws_eip.spoke2_vm1.public_ip} -i ~/.ssh/${var.key_name}.pem"
}
