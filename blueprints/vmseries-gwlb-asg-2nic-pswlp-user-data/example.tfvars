# tested with Terraform 1.1.9, Panorama 10.2.2 and VM Series 10.1.5-h1

# ~/.aws/credentials profile entry
aws_profile = "pan-lab"
region   = "us-east-2"
# query which BYOL AMI IDs are available
# $ aws --region us-east-2 ec2 describe-images --filters "Name=name,Values=PA-VM-AWS-10.1.*" "Name=product-code,Values=hd44w1chf26uv4p52cdynb2o"
panos_version="10.1.5-h1"

# Target Tracking Autoscaling
cloudwatch_namespace="VMseriesGWLB"
cloudwatch_metricname="DataPlaneCPUUtilizationPct"
cloudwatch_statistic="Average"
cloudwatch_target_value="20"

# use iperf to test auto scaling
# Server: ssh -J ubuntu@spoke2 ubuntu@10.101.0.4 nohup iperf -s 
# Client: ssh ubuntu@spoke2 iperf -w 128 -c 10.101.0.4 -i 5 -t 600 -P 5 

# ASG sizing
asg_min="2"
asg_max="2"
asg_desired="2"

# Existing AWS SSH Key Name
key_name = "pan-lab-mharms"

# hostname prefix used in launch template
fw_prefix             = "vmseries-gwlb-asg"

# minimum EC2 instance for lab
fw_size               = "m5.large"

# Minimum subnets for three AZ GWLB deployment
# AWS ASG Launch Template cannot launch instances in multiple subnets (dataplane and mgmt must be in same subnet).  
# Otherwise, must use Lifecycle hooks (launch/terminate)to manage second (mgmt) and third (egress/overlay routing) ENIs .
 
fw_vpc_cidr           = "10.100.0.0/16"
fw_cidr_natgw_az1     = "10.100.2.0/28"
fw_cidr_natgw_az2     = "10.100.2.16/28"
fw_cidr_natgw_az3     = "10.100.2.32/28"
fw_cidr_gwlbe_az1     = "10.100.3.0/28"
fw_cidr_gwlbe_az2     = "10.100.3.16/28"
fw_cidr_gwlbe_az3     = "10.100.3.32/28"
fw_cidr_tgw_az1       = "10.100.4.0/28"
fw_cidr_tgw_az2       = "10.100.4.16/28"
fw_cidr_tgw_az3       = "10.100.4.32/28"

# 2 EC2 instances (default route to inspection VPC via TGW) and ALB 
spoke1_prefix         = "spoke1"
spoke1_vpc_cidr       = "10.101.0.0/16"
spoke1_cidr_vm_az1    = "10.101.0.0/28"
spoke1_cidr_vm_az2    = "10.101.0.16/28"
spoke1_cidr_alb_az1   = "10.101.1.0/28"
spoke1_cidr_alb_az2   = "10.101.1.16/28"
spoke1_cidr_gwlbe_az1 = "10.101.2.0/28"
spoke1_cidr_gwlbe_az2 = "10.101.2.16/28"
spoke1_vm1_ip         = "10.101.0.4"
spoke1_vm2_ip         = "10.101.0.20"

# 1 EC2 instances with EIP (default route to inspection VPC via TGW), backdoor route to your IP
spoke2_prefix         = "spoke2"
spoke2_vpc_cidr       = "10.102.0.0/16"
spoke2_subnet_cidr    = "10.102.0.0/24"
spoke2_vm1_ip         = "10.102.0.4"

# EC2 instance size for workload in spoke1 and spoke2
spoke_size            = "t2.micro"

# VM Series firewall user data information
# Panorama needs to be publicly available via NAT-GW on TCP ports 3978 (Panorama Management), 28443 (Content Auto-Push) 
# and TCP 443 for Lambda connectivity to Panorama API
# Private connectivity to Panorama could be used if deployment was modified/extended to use existing privately connected resources (existing TGW and VPN/DX).

# Key to associate bootstraping VM series with Panorama with Panorma SW Licensing Plugin... 
panorama_auth_key = ""

# Panorama Template Stack and Device Group
# See panorama-set.txt
panorama_template_stack = "TS_GWLB-demo"
panorama_device_group = "DG_GWLB-demo"

# Associate VM Series with Customer Support Portal. Assets -> Device Certificates -> Registration PIN History
# Cortex Data Lake, Autofocus, etc...
# This needs to be rotated max expiry is 1 year
pan_csp_auto_reg_pin_id = ""
pan_csp_auto_reg_pin_value = ""

panorama1 = ""
panorama2 = ""

collector_group_name = ""
