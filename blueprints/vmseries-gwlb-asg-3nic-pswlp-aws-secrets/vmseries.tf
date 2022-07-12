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

  user_data_byol_secret = {
    dhcp-accept-server-hostname="yes"
    dhcp-accept-server-domain="yes"
    auth-key="${var.panorama_auth_key}"
    panorama-server="${var.panorama1}"
    panorama-server-2="${var.panorama2}"
    dgname="${var.panorama_device_group}"
    tplname="${var.panorama_template_stack}"
    vm-series-auto-registration-pin-id="${var.pan_csp_auto_reg_pin_id}"
    vm-series-auto-registration-pin-value="${var.pan_csp_auto_reg_pin_value}"
    plugin-op-commands="aws-gwlb-inspect:enable,aws-gwlb-overlay-routing:enable,panorama-licensing-mode-on"
    cgname="${var.collector_group_name}"
  }

  lambda_secret_asg = {
    panorama_pri = "${var.panorama1}"
    panorama_sec = "${var.panorama2}"
    panorama_api_key = "${var.panorama_api_key}"
  }
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
# Used before Instance ID based hostname to VM series via DHCP hostname
#  user_data = base64encode("hostname=${var.fw_prefix}-byol-asg\n${local.user_data_byol}")
# Used before aws secrets 
   user_data = base64encode("mgmt-interface-swap=enable;secret_name=${aws_secretsmanager_secret.vmseries_user_data.name}")


  private_dns_name_options {
    hostname_type = "resource-name"
  }

  update_default_version = true

}

resource "aws_placement_group" "placement_group_spread" {
  name = "spread"
  strategy = "spread"
  spread_level = "rack"
}

# need to build dependency to order destroy for BYOL.  Destroy does not trigger lifecycle hook for terminate with deactivate
# work around would be to adjust size to 0 
resource "aws_autoscaling_group" "vmseries_byol_asg" {
  name                      = "${random_id.deployment_id.hex}_byol_asg"
  max_size                  = var.asg_max
  min_size                  = var.asg_min
  desired_capacity          = var.asg_desired
  vpc_zone_identifier       = [ module.vmseries_subnets.subnet_ids["gwlbe-az1"], module.vmseries_subnets.subnet_ids["gwlbe-az2"], module.vmseries_subnets.subnet_ids["gwlbe-az3"]]
#  health_check_type         = "EC2"
#  health_check_grace_period = 300
  health_check_type         = "ELB"
  health_check_grace_period = 1920
  default_cooldown          = 2700
  default_instance_warmup   = 1900
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

# Have not figured out how to update initial launch post-deployment.  Need more research.

  initial_lifecycle_hook {
      name                  = "AutoScalingStartupLifeCycleHook"
      # IMPORTANT - DOES NOT SEEM TO UPDATE AFTER DEPLOYMENT
      default_result        = "ABANDON"
      # IMPORTANT - DOES NOT SEEM TO UPDATE AFTER DEPLOYMENT
      heartbeat_timeout     = 1920
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({
                                "secret_user_data" = "${aws_secretsmanager_secret.vmseries_user_data.name}", 
                                "secret_panorama" = "${aws_secretsmanager_secret.panorama.name}",
                                "extra_nic_subnets": { 
                                  "${module.vmseries_subnets.azs["natgw-az1"]}": "${module.vmseries_subnets.subnet_ids["natgw-az1"]}",
                                  "${module.vmseries_subnets.azs["natgw-az2"]}": "${module.vmseries_subnets.subnet_ids["natgw-az2"]}",
                                  "${module.vmseries_subnets.azs["natgw-az3"]}": "${module.vmseries_subnets.subnet_ids["natgw-az3"]}",
                                },
                              "extra_nic_sg": "${aws_security_group.vmseries_data_public.id}",
                              "license": "byol",
                              })
    }
  depends_on = [
    aws_lambda_function.asglambda,
    aws_lambda_permission.eventbridge_launch_invoke_lambda_permission
  ]

  lifecycle {
    ignore_changes = [ desired_capacity, ]

  }

}

resource "aws_autoscaling_lifecycle_hook" "AutoScalingTerminationLifeCycleHook" {
      name                  = "AutoScalingTerminationLifeCycleHook"
      autoscaling_group_name = aws_autoscaling_group.vmseries_byol_asg.name
      # IMPORTANT - DOES NOT SEEM TO UPDATE AFTER DEPLOYMENT
      default_result        = "CONTINUE"
      # IMPORTANT - DOES NOT SEEM TO UPDATE AFTER DEPLOYMENT
      heartbeat_timeout     = 900
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({ 
                                "secret_user_data" = "${aws_secretsmanager_secret.vmseries_user_data.name}", 
                                "secret_panorama" = "${aws_secretsmanager_secret.panorama.name}",
                                "license": "byol",
                                })
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

data "archive_file" "asglambda_zip" {
  type = "zip"
  output_path = "asglambda.zip"
  source_dir = "./code/"
  depends_on = [
    null_resource.python_dependencies
  ]
}

resource "null_resource" "python_dependencies" {
  provisioner "local-exec" {
    command = "pip3 install -r code/requirements.txt -t code/ --upgrade"
  }
  triggers = {
    dependencies_versions = filemd5("code/requirements.txt") 
  }
}

resource "aws_lambda_function" "asglambda" {
  function_name = "asglambda"
  runtime = "python3.9"
  filename = "${data.archive_file.asglambda_zip.output_path}"
  handler = "asglambda.lambda_handler"
  role = aws_iam_role.asglambda_role.arn
  timeout = 900
  source_code_hash = "${data.archive_file.asglambda_zip.output_base64sha256}"
 vpc_config {
    subnet_ids         = [module.vmseries_subnets.subnet_ids["gwlbe-az1"], module.vmseries_subnets.subnet_ids["gwlbe-az2"], module.vmseries_subnets.subnet_ids["gwlbe-az3"]]
    security_group_ids = [aws_security_group.vmseries_mgmt.id]
  }
}

resource aws_iam_role "asglambda_role" {
  name = "asglambda_role"
  assume_role_policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [ {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
  } ]
}
EOT
}

resource aws_iam_policy "asglambda_role_inline_policy" {
  name = "asglambda_role_inline_policy"
  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [ {
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "ec2:CreateTags",
        "secretsmanager:GetSecretValue",
        "ec2:DescribeInstances",
        "ec2:CreateNetworkInterface",
        "ec2:AttachNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeNetworkInterfaceAttribute",
        "ec2:DescribeAddresses",
        "ec2:DescribeSubnets",
        "ec2:DescribeAddressesAttribute",
        "ec2:DeleteNetworkInterface",
        "ec2:AllocateAddress",
        "ec2:AssociateAddress",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses",
        "ec2:ModifyNetworkInterfaceAttribute",
        "autoscaling:CompleteLifecycleAction"
      ]
  },
  {
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:GetLogEvents"
    ],
    "Resource": "arn:aws:logs:*:*:*",
    "Effect": "Allow"
  } ]
})
}

resource "aws_iam_role_policy_attachment" "asglambda_role_attachment" {
  role = aws_iam_role.asglambda_role.name
  policy_arn = aws_iam_policy.asglambda_role_inline_policy.arn
}

resource "aws_cloudwatch_event_rule" "vmseries_byol_asg_event_rule_launch" {
  name        = "vmseries_byol_asg_event_rule_launch"
  description = "vmseries_byol_asg_event_rule_launch"

  event_pattern = <<EOF
{
  "source": ["aws.autoscaling"],
  "detail-type": ["EC2 Instance-launch Lifecycle Action"],
  "detail": { "AutoScalingGroupName": ["${random_id.deployment_id.hex}_byol_asg" ] }
}
EOF
}

resource "aws_cloudwatch_event_rule" "vmseries_byol_asg_event_rule_terminate" {
  name        = "vmseries_byol_asg_event_rule_terminate"
  description = "vmseries_byol_asg_event_rule_terminate"

  event_pattern = <<EOF
{
  "source": ["aws.autoscaling"],
  "detail-type": ["EC2 Instance-terminate Lifecycle Action"],
  "detail": { "AutoScalingGroupName": ["${random_id.deployment_id.hex}_byol_asg" ] }
}
EOF
}

resource "aws_cloudwatch_event_target" "eventbridge_launch_lambda_target" {
  rule      = aws_cloudwatch_event_rule.vmseries_byol_asg_event_rule_launch.name
  target_id = "InvokeLambda"
  arn       = aws_lambda_function.asglambda.arn
}

resource "aws_cloudwatch_event_target" "eventbridge_terminate_lambda_target" {
  rule      = aws_cloudwatch_event_rule.vmseries_byol_asg_event_rule_terminate.name
  target_id = "InvokeLambda"
  arn       = aws_lambda_function.asglambda.arn
}

resource "aws_lambda_permission" "eventbridge_launch_invoke_lambda_permission" {
  statement_id = "AllowExecutionFromEventBridge_Launch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.asglambda.arn}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.vmseries_byol_asg_event_rule_launch.arn}"
}

resource "aws_lambda_permission" "eventbridge_terminate_invoke_lambda_permission" {
  statement_id = "AllowExecutionFromEventBridge_Terminate"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.asglambda.arn}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.vmseries_byol_asg_event_rule_terminate.arn}"
}

resource "aws_secretsmanager_secret" vmseries_user_data {
  name = "${random_id.deployment_id.hex}-${var.aws_secret_name_vmseries_asg}"
}

resource "aws_secretsmanager_secret_version" vmseries_user_data_version {
  secret_id = aws_secretsmanager_secret.vmseries_user_data.id
  secret_string = jsonencode(local.user_data_byol_secret)
}

resource "aws_secretsmanager_secret" panorama {
  name = "${random_id.deployment_id.hex}-${var.aws_secret_name_panorama}"
}

resource "aws_secretsmanager_secret_version" panorama_version {
  secret_id = aws_secretsmanager_secret.panorama.id
  secret_string = jsonencode(local.lambda_secret_asg)
}
