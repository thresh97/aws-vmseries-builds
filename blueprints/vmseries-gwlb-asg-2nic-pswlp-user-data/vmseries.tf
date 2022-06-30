module "vmseries_bootstrap" { 
  source = "../../modules/s3_bootstrap/" 
 
  file_location           = "bootstrap_files/" 
  bucket_name             = "vmseries-bootstrap-${random_string.main.result}" 
  config                  = ["bootstrap.xml", "init-cfg.txt"] 
  license                 = ["authcodes"] 
  content                 = [] 
  software                = [] 
  other                   = [] 
  create_instance_profile = true 
}

data "aws_ami" "vmseries_byol" {
  most_recent = true

  filter {
    name   = "name"
    values = ["PA-VM-AWS-${var.panos_version}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "product-code"
    values = ["6njl1pau431dv1qxipg63mvah"]
  }

  owners = ["679593333241"] 
}

locals {
  user_data_byol      = <<EOT
dhcp-accept-server-hostname=yes
dhcp-accept-server-domain=yes
auth-key=${var.panorama_auth_key}
panorama-server=${var.panorama1}
panorama-server-2=${var.panorama2}
dgname=${var.panorama_device_group}
tplname=${var.panorama_template_stack}
vm-series-auto-registration-pin-id=${var.pan_csp_auto_reg_pin_id}
vm-series-auto-registration-pin-value=${var.pan_csp_auto_reg_pin_value}
mgmt-interface-swap=enable
plugin-op-commands=aws-gwlb-inspect:enable,panorama-licensing-mode-on
cgname=${var.collector_group_name}
EOT

}

resource "aws_security_group" "vmseries_mgmt" {
  vpc_id      = aws_vpc.security.id
  description = "VM-Series Management SG"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = var.private_routes
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vmseries-mgmt-sg"
  }
}

resource "aws_security_group" "vmseries_data" {
  vpc_id      = aws_vpc.security.id
  description = "VM-Series Dataplane SG"

  ingress {
    from_port   = "-1"
    to_port     = "-1"
    protocol    = "1"
    cidr_blocks = var.private_routes
  }

  ingress {
    from_port   = "8"
    to_port     = "8"
    protocol    = "6"
    cidr_blocks = [var.fw_vpc_cidr]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "6"
    cidr_blocks = [var.fw_vpc_cidr]
  }

  ingress {
    from_port   = "6081"
    to_port     = "6081"
    protocol    = "17"
    cidr_blocks = [var.fw_vpc_cidr]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vmseries-data-sg"
  }
}

resource "aws_security_group" "vmseries_data_public" {
  vpc_id      = aws_vpc.security.id
  description = "VM-Series Public Dataplane SG"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["${data.http.myip.body}/32"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vmseries-data-public-sg"
  }
}

resource "aws_launch_template" "vmseries_byol" {
  name = "${random_id.deployment_id.hex}_byol_lt"
  image_id = data.aws_ami.vmseries_byol.id
  instance_type = var.fw_size
  key_name = var.key_name
  network_interfaces {
      device_index = "0"
      description = "en0"
      security_groups = [ aws_security_group.vmseries_data.id ]
  }
  network_interfaces {
      device_index = "1"
      description = "en1"
      security_groups = [ aws_security_group.vmseries_mgmt.id ]
      delete_on_termination = "true"
  }

  iam_instance_profile {
    name = module.vmseries_bootstrap.instance_profile
  }

  tags = {
    LTName = "vmseries-byol-lt"
    propagate_at_launch = true
  }

  block_device_mappings {
      device_name = "/dev/xvda"
      ebs {
        volume_type = "gp2"
        delete_on_termination = "true"
        volume_size = 60
      }
  }
  user_data = base64encode("${local.user_data_byol}")

  private_dns_name_options {
    hostname_type = "resource-name"
  }

  update_default_version = true

}

resource "aws_placement_group" "placement_group_spread" {
  name = "spread"
  strategy = "spread"
}

# need to build dependency to order destroy for BYOL.  Destroy does not trigger lifecycle hook for terminate with deactivate
# work around would be to adjust size to 0 
resource "aws_autoscaling_group" "vmseries_byol_asg" {
  name                      = "${random_id.deployment_id.hex}_byol_asg"
  max_size                  = var.asg_max
  min_size                  = var.asg_min
  desired_capacity          = var.asg_desired
  vpc_zone_identifier       = [ module.vmseries_subnets.subnet_ids["gwlbe-az1"], module.vmseries_subnets.subnet_ids["gwlbe-az2"], module.vmseries_subnets.subnet_ids["gwlbe-az3"]]
  health_check_type         = "ELB"
  health_check_grace_period = 1800
  default_cooldown          = 2700
  placement_group           = aws_placement_group.placement_group_spread.id
  force_delete              = true
  
  metrics_granularity       = "1Minute"
  enabled_metrics           = ["GroupDesiredCapacity","GroupInServiceCapacity","GroupPendingCapacity","GroupMinSize","GroupMaxSize",
                                "GroupInServiceInstances","GroupPendingInstances","GroupStandbyInstances","GroupStandbyCapacity",
                                "GroupTerminatingCapacity","GroupTerminatingInstances","GroupTotalCapacity","GroupTotalInstances"]
  wait_for_capacity_timeout = "0"
  tag {
    key                 = "Name"
    value               = var.fw_prefix
    propagate_at_launch = true
  }
  tag {
    key                 = "serial"
    value               = "unknown"
    propagate_at_launch = true
  }
  tag {
    key                 = "license"
    value               = "byol"
    propagate_at_launch = true
  }
  launch_template {
      id = aws_launch_template.vmseries_byol.id
      version = aws_launch_template.vmseries_byol.latest_version
  }

  target_group_arns = [ aws_lb_target_group.gwlb.id ]

}

resource "aws_autoscaling_policy" "byol_tt" {
  name                   = "${random_id.deployment_id.hex}_asg_policy_byol_tt"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.vmseries_byol_asg.name

  target_tracking_configuration {
    customized_metric_specification {
        metric_name       = var.cloudwatch_metricname
        namespace         = var.cloudwatch_namespace
        statistic         = var.cloudwatch_statistic
    }
  
    target_value = var.cloudwatch_target_value
  }
}
