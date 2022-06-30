# tested with Terraform 1.1.9, Panorama 10.1.6-h3 and VM Series 10.1.5-h1

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

# Warm pool size
# By default, the size of the warm pool is calculated as the difference between the Auto Scaling group's maximum capacity and its desired capacity. 
# For example, if the desired capacity of your Auto Scaling group is 6 and the maximum capacity is 10, the size of your warm pool will be 4 when you 
# first set up the warm pool and the pool is initializing.
# update below ASG instance counts to 0 before "terraform destroy" to cleanup CSP licensing
asg_min="1"
asg_max="1"
asg_desired="1"
asg_prepared_min="1"
# terminate all instances in ASG prior to terraform destroy to cleanup panorama and CSP licensing for BYOL with the following commands
# aws --profile pan-lab --region us-east-2 autoscaling put-warm-pool --auto-scaling-group-name PANW-GWLB-065b_byol_asg --min-size 0
# aws --profile pan-lab --region us-east-2 autoscaling update-auto-scaling-group --auto-scaling-group-name PANW-GWLB-065b_byol_asg --min-size 0 --max-size 0 --desired-capacity 0 

# Existing AWS SSH Key Name
key_name = "<existing-ssh-key-pair-name>

# hostname prefix used in launch template
fw_prefix             = "vmseries-gwlb-overlay-asg"

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

aws_secret_name_vmseries_asg = "vmseries_secret_for_user_data"
aws_secret_name_panorama = "panorama_secret_for_lambda"

# VM Series firewall user data information
# Panorama must be 10.2.x for Content Auto Push to Bootstapping firewall
# Panorama needs to be publicly available via NAT-GW on TCP ports 3978 (Panorama Management), 28443 (Content Auto-Push) 
# and TCP 443 for Lambda connectivity to Panorama API
# Private connectivity to Panorama could be used if deployment was modified/extended to use existing privately connected resources (existing TGW and VPN/DX).

# Key to associate bootstraping VM series with Panorama - request bootstrap vm-auth-key ... 
# (1 year max - need process to update user_data or AWS Secrets used in launch template)
panorama_vm_auth_key="123412341234123"

# Authcode for BYOL (ELA/FW Flex/Perp)
# BYOL ASG is fixed size min==max instances.   
# update ASG instance counts to 0 before "terraform destroy"
authcode = "D1231234"

# Panorama Template Stack and Device Group
# See panorama-set.txt
panorama_template_stack="TS_GWLB-demo"
panorama_device_group="DG_GWLB-demo"

# Associate VM Series with Customer Support Portal. Assets -> Device Certificates -> Registration PIN History
# Cortex Data Lake, Autofocus, etc...
# This needs to be rotated max expiry is 1 year
pan_csp_auto_reg_pin_id="12345678-1234-1234-1234-123456789012"
pan_csp_auto_reg_pin_value="12345678901234567890123456789012"

panorama1 = "192.0.2.1"
panorama2 = "198.51.100.1"

# The Panorama API Key should be rotated 
# panxapi.py -h 192.0.2.1 -l api_user:password -k
panorama_api_key = "LUaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaQ=="
collector_group_name = ""
