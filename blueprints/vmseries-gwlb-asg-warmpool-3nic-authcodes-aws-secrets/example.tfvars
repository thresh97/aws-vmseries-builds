# tested with Terraform 1.1.9

# ~/.aws/credentials profile entry
aws_profile = "pan-lab"
region   = "us-east-2"
panos_version="10.1.5-h1"

# Decrypt Demo
#decrypt_inbound  = "wildcard.example.com"
#decrypt_inbound  = "false"
#spoke1_acm_arn = "arn:aws:acm:us-east-2:123412341234:certificate/asdfasdfasdf"

# VM Series firewall user data information
# Panorama must be 10.2.x for Content Auto Push to Bootstapping firewall
# Panorama needs to be publicly available via NAT-GW on TCP ports 3978 (Panorama Management) and 28443 (Content Auto-Push) 
# Private connectivity to Panorama could be used if deployment was modified/extended to use existing privately connected resources (existing TGW and VPN/DX).
panorama1 = "54.189.118.231"

# Key to associate bootstraping VM series with Panorama - request bootstrap vm-auth-key ... (1 year max - need process to update user_data on launch template)
panorama_vm_auth_key="071540710486976"

# Authcode for BYOL (ELA/FW Flex/Perp)
# BYOL ASG is fixed size min==max instances.   Termination requires manual delicensing in CSP portal.
authcode = "D4814653"

# Panorama Template Stack and Device Group
# See panorama-set.txt
# Panorama must be 10.2.x for Content Auto Push to Bootstapping firewall
panorama_template_stack="TS_GWLB-demo"
panorama_device_group="DG_GWLB-demo"

# Associate VM Series with Customer Support Portal. Assets -> Device Certificates -> Registration PIN History
pan_csp_auto_reg_pin_id="e38e0925-478c-4aae-a3bf-c7431c023191"
pan_csp_auto_reg_pin_value="2222"

# generate traffic with mtr from spoke2 VM to spoke1 VMs
cloudwatch_namespace="VMseriesGWLB"
cloudwatch_metricname="panSessionActive"
cloudwatch_threshold_low_alarm="16"
cloudwatch_threshold_high_alarm="17"

# Existing AWS SSH Key Name
key_name = "pan-lab-mharms"

# IP to use for inbound SSH access to spoke 2 VM used in SG and EC2 Instance Route Table
your_public_ip = "108.76.182.46"

# hostname prefix used in launch template
fw_prefix             = "vmseries-intra-zone"

# minimum EC2 instance for lab
fw_size               = "m5.large"

# Minimum subnets for three AZ GWLB deployment
# AWS ASG Launch Template cannot launch instances in multiple subnets (dataplane and mgmt must be in same subnet).  
# Otherwise, must use Lifecycle hooks (launch/terminate)to manage secondary ENIs.
 
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

spoke2_prefix         = "spoke2"
spoke2_vpc_cidr       = "10.102.0.0/16"
spoke2_subnet_cidr    = "10.102.0.0/24"
spoke2_vm1_ip         = "10.102.0.4"

# EC2 instance size for workload in spoke1 and spoke2
spoke_size            = "t2.micro"
