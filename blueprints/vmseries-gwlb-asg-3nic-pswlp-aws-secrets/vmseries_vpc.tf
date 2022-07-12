#------------------------------------------------------------------------------------------------------------------------------------
# Create firewall VPC, subnets, & IGW
resource "aws_vpc" "security" {
  cidr_block = var.fw_vpc_cidr

  tags = {
    Name = "${var.fw_prefix}-vpc"
    IpType = "vpc"
  }
}

resource "aws_internet_gateway" "security" {
  vpc_id = aws_vpc.security.id

  tags = {
    Name = "${var.fw_prefix}-vpc"
  }

}

resource "aws_eip" eip_nat_gw_az1 {
  vpc = true
}

resource "aws_eip" eip_nat_gw_az2 {
  vpc = true
}

resource "aws_eip" eip_nat_gw_az3 {
  vpc = true
}



resource "aws_nat_gateway" nat_gw_az1 {
  allocation_id = aws_eip.eip_nat_gw_az1.id
  subnet_id = module.vmseries_subnets.subnet_ids["natgw-az1"]
}


resource "aws_nat_gateway" nat_gw_az2 {
  allocation_id = aws_eip.eip_nat_gw_az2.id
  subnet_id = module.vmseries_subnets.subnet_ids["natgw-az2"]
}

resource "aws_nat_gateway" nat_gw_az3 {
  allocation_id = aws_eip.eip_nat_gw_az3.id
  subnet_id = module.vmseries_subnets.subnet_ids["natgw-az3"]
}


module "vmseries_subnets" {
  source = "../../modules/subnets/"
  vpc_id = aws_vpc.security.id
  subnet_name_prefix = "${var.fw_prefix}-"

  subnets = {
    natgw-az1 = {
      az   = data.aws_availability_zones.available.names[0]
      cidr = var.fw_cidr_natgw_az1
      DecryptInbound = "false"
      DecryptOutbound = "false"
    },
    natgw-az2 = {
      az   = data.aws_availability_zones.available.names[1]
      cidr = var.fw_cidr_natgw_az2
      DecryptInbound = "false"
      DecryptOutbound = "false"
    },
    natgw-az3 = {
      az   = data.aws_availability_zones.available.names[2]
      cidr = var.fw_cidr_natgw_az3
      DecryptInbound = "false"
      DecryptOutbound = "false"
    },
    gwlbe-az1 = {
      az   = data.aws_availability_zones.available.names[0]
      cidr = var.fw_cidr_gwlbe_az1
      DecryptInbound = "false"
      DecryptOutbound = "false"
    },
    gwlbe-az2 = {
      az   = data.aws_availability_zones.available.names[1]
      cidr = var.fw_cidr_gwlbe_az2
      DecryptInbound = "false"
      DecryptOutbound = "false"
    },
    gwlbe-az3 = {
      az   = data.aws_availability_zones.available.names[2]
      cidr = var.fw_cidr_gwlbe_az3
      DecryptInbound = "false"
      DecryptOutbound = "false"
    },
    tgw-az1 = {
      az   = data.aws_availability_zones.available.names[0]
      cidr = var.fw_cidr_tgw_az1
      DecryptInbound = "false"
      DecryptOutbound = "false"
    },
    tgw-az2 = {
      az   = data.aws_availability_zones.available.names[1]
      cidr = var.fw_cidr_tgw_az2
      DecryptInbound = "false"
      DecryptOutbound = "false"
    }
    tgw-az3 = {
      az   = data.aws_availability_zones.available.names[2]
      cidr = var.fw_cidr_tgw_az3
      DecryptInbound = "false"
      DecryptOutbound = "false"
    }

  }
}

resource "aws_route_table" "natgw_az1" {
  vpc_id = aws_vpc.security.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.security.id
  }

  dynamic "route" {
    for_each = var.private_routes
      content {
        cidr_block      = route.value
        vpc_endpoint_id = aws_vpc_endpoint.az1.id
      }
  }

  tags = {
    Name = "natgw-az1-rtb"
  }
}

resource "aws_route_table" "natgw_az2" {
  vpc_id = aws_vpc.security.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.security.id
  }

  dynamic "route" {
    for_each = var.private_routes
      content {
        cidr_block      = route.value
        vpc_endpoint_id = aws_vpc_endpoint.az2.id
      }
  }

  tags = {
    Name = "natgw-az2-rtb"
  }
}

resource "aws_route_table" "natgw_az3" {
  vpc_id = aws_vpc.security.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.security.id
  }

  dynamic "route" {
    for_each = var.private_routes
      content {
        cidr_block      = route.value
        vpc_endpoint_id = aws_vpc_endpoint.az3.id
      }
  }

  tags = {
    Name = "natgw-az3-rtb"
  }
}


resource "aws_route_table" "gwlbe_az1" {
  vpc_id = aws_vpc.security.id

  dynamic "route" {
    for_each = var.private_routes
      content {
        cidr_block      = route.value
        transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.main.transit_gateway_id
      }
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_az1.id
  }


  tags = {
    Name = "gwlbe-az1-rtb"
  }
}

resource "aws_route_table" "gwlbe_az2" {
  vpc_id = aws_vpc.security.id
  
  dynamic "route" {
    for_each = var.private_routes
      content {
        cidr_block      = route.value
        transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.main.transit_gateway_id
      }
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_az2.id
  }

  tags = {
    Name = "gwlbe-az2-rtb"
  }
}

resource "aws_route_table" "gwlbe_az3" {
  vpc_id = aws_vpc.security.id
  
  dynamic "route" {
    for_each = var.private_routes
      content {
        cidr_block      = route.value
        transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.main.transit_gateway_id
      }
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_az3.id
  }

  tags = {
    Name = "gwlbe-az3-rtb"
  }
}

resource "aws_route_table" "tgw_az1" {
  vpc_id = aws_vpc.security.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.az1.id
  }

  tags = {
    Name = "tgw-az1-rtb"
  }
}

resource "aws_route_table" "tgw_az2" {
  vpc_id = aws_vpc.security.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.az2.id
  }

  tags = {
    Name = "tgw-az2-rtb"
  }
}

resource "aws_route_table" "tgw_az3" {
  vpc_id = aws_vpc.security.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.az3.id
  }

  tags = {
    Name = "tgw-az3-rtb"
  }
}

module "rtb_association_gwlbe_az1" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.gwlbe_az1.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["gwlbe-az1"]
  ]
}

module "rtb_association_gwlbe_az2" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.gwlbe_az2.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["gwlbe-az2"]
  ]
}

module "rtb_association_gwlbe_az3" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.gwlbe_az3.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["gwlbe-az3"]
  ]
}

module "rtb_association_tgw_az1" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.tgw_az1.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["tgw-az1"]
  ]
}

module "rtb_association_tgw_az2" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.tgw_az2.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["tgw-az2"]
  ]
}

module "rtb_association_tgw_az3" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.tgw_az3.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["tgw-az3"]
  ]
}

module "rtb_association_natgw_az1" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.natgw_az1.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["natgw-az1"],
  ]
}

module "rtb_association_natgw_az2" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.natgw_az2.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["natgw-az2"]
  ]
}

module "rtb_association_natgw_az3" {
  source         = "../../modules/route_table_association/"
  route_table_id = aws_route_table.natgw_az3.id

  subnet_ids = [
    module.vmseries_subnets.subnet_ids["natgw-az3"]
  ]
}
