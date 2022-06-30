#-----------------------------------------------------------------------------------------------
# Create Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description                     = "Demo Transit Gateway"
  vpn_ecmp_support                = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"

  tags = {
    Name = "${random_id.deployment_id.hex}_${var.fw_prefix}-tgw"
  }

}


#-----------------------------------------------------------------------------------------------
# Attach security VPC to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  vpc_id = aws_vpc.security.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["tgw-az1"],
    module.vmseries_subnets.subnet_ids["tgw-az2"],
    module.vmseries_subnets.subnet_ids["tgw-az3"]
  ]

  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  appliance_mode_support                          = "enable"
  tags = {
    Name = "${random_id.deployment_id.hex}_${var.fw_prefix}-attach"
  }
}


resource "aws_ec2_transit_gateway_route_table" "fw_common" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_route_table_association" "fw_common" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.fw_common.id
}

resource "aws_ec2_transit_gateway_route" "spoke1" {
  destination_cidr_block         = var.spoke1_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke1_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.fw_common.id
}

resource "aws_ec2_transit_gateway_route" "spoke2" {
  destination_cidr_block         = var.spoke2_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke2_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.fw_common.id
}


# -----------------------------------------------------------------------------------------------
# Attach Spoke2 VPC to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke2_attachment" {
  vpc_id = aws_vpc.spoke2.id

  subnet_ids                                      = [aws_subnet.spoke2.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "${random_id.deployment_id.hex}_${var.spoke2_prefix}-attach"
  }
}

# -----------------------------------------------------------------------------------------------
# Attach Spoke1 VPC to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke1_attachment" {
  vpc_id = aws_vpc.spoke1.id

  subnet_ids = [
    module.spoke1_subnets.subnet_ids["vm-az1"],
    module.spoke1_subnets.subnet_ids["vm-az2"]
  ]

  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "${random_id.deployment_id.hex}_${var.spoke1_prefix}-attach"
  }
}

resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
}

resource "aws_ec2_transit_gateway_route" "spoke" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke1_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke2_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}





