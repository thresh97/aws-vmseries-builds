# --- PROVIDER CONFIGURATION ---
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# --- VARIABLES ---

variable "region" {
  type        = string
  description = "AWS Region (e.g., us-west-2)"
  default     = "us-west-2"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "allowed_mgmt_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the management interfaces"
  default     = ["0.0.0.0/0"]
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an existing AWS Key Pair"
}

variable "vmseries_instance_type" {
  type        = string
  description = "Instance type for VM-Series (e.g., m5.xlarge, c5.xlarge)"
  default     = "m5.xlarge"
}

variable "panos_version" {
  type        = string
  description = "PAN-OS Version to search for in Marketplace"
  default     = "11.1.0"
}

variable "vmseries_bootstrap_custom_1" {
  type        = string
  description = "Bootstrap configuration for Firewall 1"
}

variable "vmseries_bootstrap_custom_2" {
  type        = string
  description = "Bootstrap configuration for Firewall 2"
}

variable "linux_user_data_base64" {
  type        = string
  description = "Base64 encoded user data for the Linux worker"
  default     = ""
}

# --- DATA SOURCES ---

data "aws_availability_zones" "available" {
  state = "available"
}

# Find latest Palo Alto BYOL AMI
data "aws_ami" "pa_vm" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["PA-VM-AWS-${var.panos_version}*"]
  }

  filter {
    name   = "product-code"
    values = ["6njl1pau431dv1qxipg63mvah"] # Product code for BYOL
  }
}

# Find Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# --- PLACEMENT GROUP ---

resource "aws_placement_group" "fw_spread" {
  name     = "pavm-rack-spread"
  strategy = "spread" # Ensures instances are on distinct racks within the AZ
  tags     = { Name = "pavm-rack-spread" }
}

# --- NETWORKING ---

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "pavm-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "pavm-igw" }
}

# --- SUBNETS (Single AZ) ---
# Subnet indices updated: 1=Mgmt, 2=Untrust, 3=Trust, 4=Workload, 5=HA
# AWS Reserved IPs: .0 (Network), .1 (Router), .2 (DNS), .3 (Future)
# First usable IP = .4
# Second usable IP = .5

resource "aws_subnet" "mgmt" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "mgmt-subnet" }
}

resource "aws_subnet" "untrust" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "untrust-subnet" }
}

resource "aws_subnet" "trust" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 3)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "trust-subnet" }
}

resource "aws_subnet" "workload" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 4)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "workload-subnet" }
}

resource "aws_subnet" "ha" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 5)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "ha-subnet" }
}

# --- ROUTE TABLES ---

# Public Route Table (Mgmt & Untrust)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "pavm-public-rt" }
}

resource "aws_route_table_association" "mgmt_assoc" {
  subnet_id      = aws_subnet.mgmt.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "untrust_assoc" {
  subnet_id      = aws_subnet.untrust.id
  route_table_id = aws_route_table.public.id
}

# Workload Route Table (Transit via Firewall)
resource "aws_route_table" "workload" {
  vpc_id = aws_vpc.this.id

  # 0/0 Route pointing to primary FW1 trust ENI
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.fw1_trust.id
  }

  # Specific routes for management CIDRs to go through IGW
  # This ensures direct return traffic for administrative access
  dynamic "route" {
    for_each = toset(var.allowed_mgmt_cidrs)
    content {
      cidr_block = route.value
      gateway_id = aws_internet_gateway.igw.id
    }
  }

  tags = { Name = "pavm-workload-rt" }
}

resource "aws_route_table_association" "workload_assoc" {
  subnet_id      = aws_subnet.workload.id
  route_table_id = aws_route_table.workload.id
}

# --- SECURITY GROUPS ---

resource "aws_security_group" "mgmt_sg" {
  name        = "pavm-mgmt-sg"
  description = "Allow Management Access"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_mgmt_cidrs
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_mgmt_cidrs
  }
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = var.allowed_mgmt_cidrs
  }
  ingress {
    from_port   = 0 
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ var.vpc_cidr ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "untrust_sg" {
  name        = "pavm-untrust-sg"
  description = "Allow Untrust Traffic"
  vpc_id      = aws_vpc.this.id

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
}

resource "aws_security_group" "trust_sg" {
  name        = "pavm-trust-sg"
  description = "Allow Trust Traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ha_sg" {
  name        = "pavm-ha-sg"
  description = "Allow HA Traffic"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
}

# --- IAM ROLE ---
resource "aws_iam_role" "fw_role" {
  name = "PA-VM-Series-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "fw_policy" {
  name        = "PA-VM-Series-Policy"
  description = "Allow PA-VM to manage Route Tables, Secondary IPs, and CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logging and Metrics
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # Route Table and Secondary IP Management for HA
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeRouteTables",
          "ec2:ReplaceRoute",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_fw_policy" {
  role       = aws_iam_role.fw_role.name
  policy_arn = aws_iam_policy.fw_policy.arn
}

resource "aws_iam_instance_profile" "fw_profile" {
  name = "PA-VM-Series-Profile"
  role = aws_iam_role.fw_role.name
}

# --- NETWORK INTERFACES (FW1) ---
# IP .4 = First usable
# IP .100 = Floating VIP (Secondary)

resource "aws_network_interface" "fw1_mgmt" {
  subnet_id       = aws_subnet.mgmt.id
  security_groups = [aws_security_group.mgmt_sg.id]
  private_ips     = [cidrhost(aws_subnet.mgmt.cidr_block, 4)]
  description     = "fw1-mgmt"
}

resource "aws_network_interface" "fw1_untrust" {
  subnet_id         = aws_subnet.untrust.id
  security_groups   = [aws_security_group.untrust_sg.id]
  source_dest_check = false
  description       = "fw1-untrust"
  # Primary IP .4, Secondary VIP .100
  private_ip_list_enabled = true
  private_ip_list = [
    cidrhost(aws_subnet.untrust.cidr_block, 4),
    cidrhost(aws_subnet.untrust.cidr_block, 100)
  ]
}

resource "aws_network_interface" "fw1_trust" {
  subnet_id         = aws_subnet.trust.id
  security_groups   = [aws_security_group.trust_sg.id]
  source_dest_check = false
  description       = "fw1-trust"
  # Primary IP .4, Secondary VIP .100
  private_ip_list_enabled = true
  private_ip_list = [
    cidrhost(aws_subnet.trust.cidr_block, 4),
    cidrhost(aws_subnet.trust.cidr_block, 100)
  ]
}

resource "aws_network_interface" "fw1_ha" {
  subnet_id       = aws_subnet.ha.id
  security_groups = [aws_security_group.ha_sg.id]
  private_ips     = [cidrhost(aws_subnet.ha.cidr_block, 4)]
  description     = "fw1-ha"
}

# --- NETWORK INTERFACES (FW2) ---
# IP .5 = Second usable

resource "aws_network_interface" "fw2_mgmt" {
  subnet_id       = aws_subnet.mgmt.id
  security_groups = [aws_security_group.mgmt_sg.id]
  private_ips     = [cidrhost(aws_subnet.mgmt.cidr_block, 5)]
  description     = "fw2-mgmt"
}

resource "aws_network_interface" "fw2_untrust" {
  subnet_id         = aws_subnet.untrust.id
  security_groups   = [aws_security_group.untrust_sg.id]
  source_dest_check = false
  description       = "fw2-untrust"
  private_ips       = [cidrhost(aws_subnet.untrust.cidr_block, 5)]
}

resource "aws_network_interface" "fw2_trust" {
  subnet_id         = aws_subnet.trust.id
  security_groups   = [aws_security_group.trust_sg.id]
  source_dest_check = false
  description       = "fw2-trust"
  private_ips       = [cidrhost(aws_subnet.trust.cidr_block, 5)]
}

resource "aws_network_interface" "fw2_ha" {
  subnet_id       = aws_subnet.ha.id
  security_groups = [aws_security_group.ha_sg.id]
  private_ips     = [cidrhost(aws_subnet.ha.cidr_block, 5)]
  description     = "fw2-ha"
}

# --- HA FAILOVER NOTES ---
# 1. On failover, PAN-OS must perform an API call (via AWS Plugin) to:
#    a. Move the Secondary Private IP (.100) from FW1 ENIs to FW2 ENIs.
#    b. Update the Workload Route Table (aws_route_table.workload) 
#       to point the 0.0.0.0/0 route to FW2's Trust ENI.
# 2. Interface (ENI) moving is not supported on ENA instances.

# --- ELASTIC IPs ---
resource "aws_eip" "linux_worker_eip" {
  domain            = "vpc"
  instance = aws_instance.linux_worker.id
}


resource "aws_eip" "fw1_mgmt_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.fw1_mgmt.id
}

# VIP EIP - Mapped to the .100 Secondary IP on FW1
resource "aws_eip" "untrust_vip_eip" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.fw1_untrust.id
  associate_with_private_ip = cidrhost(aws_subnet.untrust.cidr_block, 100)
}

resource "aws_eip" "fw2_mgmt_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.fw2_mgmt.id
}

# --- COMPUTE INSTANCES (FIREWALLS) ---

resource "aws_instance" "fw1" {
  ami                  = data.aws_ami.pa_vm.id
  instance_type        = var.vmseries_instance_type
  key_name             = var.ssh_key_name
  iam_instance_profile = aws_iam_instance_profile.fw_profile.name
  user_data            = var.vmseries_bootstrap_custom_1
  placement_group      = aws_placement_group.fw_spread.id

  # SCP Compliance: Force GP3 root volume
  root_block_device {
    volume_type = "gp3"
    delete_on_termination = true
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.fw1_mgmt.id
  }

  network_interface {
    device_index         = 3
    network_interface_id = aws_network_interface.fw1_untrust.id
  }

  network_interface {
    device_index         = 2
    network_interface_id = aws_network_interface.fw1_trust.id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.fw1_ha.id
  }

  tags = { Name = "PA-VM-FW1" }
}

resource "aws_instance" "fw2" {
  ami                  = data.aws_ami.pa_vm.id
  instance_type        = var.vmseries_instance_type
  key_name             = var.ssh_key_name
  iam_instance_profile = aws_iam_instance_profile.fw_profile.name
  user_data            = var.vmseries_bootstrap_custom_2
  placement_group      = aws_placement_group.fw_spread.id

  # SCP Compliance: Force GP3 root volume
  root_block_device {
    volume_type = "gp3"
    delete_on_termination = true
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.fw2_mgmt.id
  }

  network_interface {
    device_index         = 3
    network_interface_id = aws_network_interface.fw2_untrust.id
  }

  network_interface {
    device_index         = 2
    network_interface_id = aws_network_interface.fw2_trust.id
  }

  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.fw2_ha.id
  }

  tags = { Name = "PA-VM-FW2" }
}

# --- LINUX WORKER ---

resource "aws_instance" "linux_worker" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = var.ssh_key_name
  subnet_id     = aws_subnet.workload.id
  vpc_security_group_ids = [aws_security_group.mgmt_sg.id]

  user_data = var.linux_user_data_base64 != "" ? base64decode(var.linux_user_data_base64) : <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Deployed via Terraform on AWS (Single AZ)</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = { Name = "Linux-Worker" }
}

# --- OUTPUTS ---

output "fw1_mgmt_ip" {
  value = aws_eip.fw1_mgmt_eip.public_ip
}

output "fw2_mgmt_ip" {
  value = aws_eip.fw2_mgmt_eip.public_ip
}

output "untrust_vip_public_ip" {
  value = aws_eip.untrust_vip_eip.public_ip
}

output "linux_worker_public_ip" {
  value = aws_eip.linux_worker_eip.public_ip
}
