# vmseries-gwlb-asg-warmpool-3nic-authcodes-aws-secrets


### Overview
This blueprint builds an AWS Autoscaling Group with Warmpool of VM Series NGFW firewalls integrated with a GWLB.  This is a greenfield deployment that is similar to the PAN VM Series Centralized AWS GWLB Reference Architecture with Centralized Egress and E/W Inspection via TGW and Distributed Ingress inspection.  It uses AWS Secrets for Basic instance meta-data based bootstrapping.  It also uses two dataplane interfaces with the optional overlay routing functionality of the GWLB VM series integration.  This is intended for demo, non-prod, and/or sandbox use.  It is not production grade.

# Infrastructure Components
- TGW
  - 3 VPC Attachements
  - 2 TGW Route Tables
    - Security
    - Inspection
- VPC
  - spoke1 (2 AZs)
    - subnets
      - 2 gwlbe subnets (1 per AZ)
      - 2 alb subnets (1 per AZ)
      - 2 vm subnets (1 per AZ)
    - 2 GWLBE (ALB Ingress)
    - route tables
      - IGW RTB
      - 1 VM RTB
      - 2 GWLBE RTB (1 per AZ)
      - 2 ALB RTB (1 per AZ)
    - 2 EC2 Instances web servers
    - 1 ALB with HTTP listner and TG with web servers
    - 1 IGW
  - spoke2 (1 AZ)
    - 1 subnet
    - 1 route table
    - 1 ec2 web server/jumpbox with EIP and route to public IP of deployment workstation for SSH access
    - 1 EIP
    - 1 IGW
  - security (3 AZs)
    - subnets
      - 3 nat-gw subnets (1 per AZ)
      - 3 gwlb subnets (1 per AZ)
      - 3 tgw subnets (1 per AZ)
     - route tables
        - 3 nat-gw subnets (1 per AZ)
        - 3 gwlb subnets (1 per AZ)
        - 3 tgw subnets (1 per AZ)
     - 3 GWLBE (combined OB and EW)
     - 3 NAT-GW
     - 3 EIP for NAT-GW
     - 1 IGW
     - 1 GWLB
- AWS Secrets
  - Panorama secrets
  - VM Series User Data
- Lambda script for lifecycle hooks
- EventBridge Rules to Execute Lambda on ASG Launch or Terminate
- Lambda Permsission for EventBridge
- IAM Inline Policy for Lambda
- Instance Profile for Launch Template and related policy
- Launch Template for ASG
- Placement Group
- ASG
  - 2 Lifecycle Hooks
  - Autoscaling Policy (Target Tracking)

# parameters
- Panorama with public IP (can be A/P)
- Panorama API key
- Panorama vm-auth-key 
- Device Certificate registration PIN ID and Value
- Collector Group Name
- Template Stack Name
- Device Group Name
- Authcode for VM Series with sufficient capacity to provision at least maximum size of ASG
- public SSH key-pair name in AWS region that ASG will be deployed

# comments
- lifecycle lambda function does the following:
  - cold launch (EC2 to Warmpool or EC2 to Autoscaling Group)
    - add second dataplane NIC with EIP
    - monitor bootstrap of VM Series via CloudWatch Group
    - find active panorama
    - tag instance with license type and serial number
    - push content and av
    - push template stack and device group
  - warm launch (Warmpool to Autoscaling Group)
    - find active panorama
    - if needed, push content and/or av
    - if needed, push DG and TS
  - terminate (Autoscaling or Warmpool to EC2)
    - remove device from panorama
    - deactivate license by serial
  - terminate for reuse (Autoscaling to Warmpool)
    - no-op
- hostnames in Panorama are the AWS instance IDs.  This is accomplished by using resource based naming in the launch template and using dhcp-accept-server-hostname=yes in user data.
- the lifecycle lambda function does not interact directly with API on VM series.  It only uses python3 boto3 to AWS and PAN-OS XML to Panorama.
- this deployment utilizes basic bootstrapping.  No S3 buckets.  No bootstrap.xml.  No init-cfg.txt
- see the scripts/ directory for panorama configuration and commands
- zero out ASG instances before terraform destroy
- destroy will take at least 20 minutes must wait on Lambda ENIs to disappear
- make sure AWS account has EIP limit to support 4 (3 sec VPC NAT-GW, 1 spoke2 VM) + maximum ASG size
- ASG ELB health checks will eventually terminate instances if commit-all from Panorama fails.
- Health check test both dataplane interfaces via SNAT/DNAT policy to TCP port 8 that redirects to metadata AWS web server
- GWLB will not send traffic to any VM Series unless Health Check validates dataplane.  This should avoid blackholing traffic associated with management profile based health checks.
- AWS Secrets reference in user-data of launch template allow for vm-auth-key, Panorama API, device registration PIN ID/Value to be rotated
- It is helpful to have panxapi.py and aws cli installed and configured
- This deployment will support a maximum of 21 VM series instances.  This is the limitation of spread placement groups.  7 instances per AZ.
- Cold Launches will take about 25 minutes.  Warm Launches will take about 5 minutes.

# future
- Probably should have less logging from Lambda script (debug flag)
- Rolling instace refresh for version upgrades
- More robust testing and selection of Panorama
- Local destroy provisioner to zero out ASG at destroy
- Lambda for AWS Secrets rotation
- More testing of Logging (Cortex Data Lake and/or Log Collector)


## Support Policy
This solution is released under an as-is, best effort, support policy. These scripts should be seen as community supported and Palo Alto Networks will contribute our expertise as and when possible. We do not provide technical support or help in using or troubleshooting the components of the project through our normal support options such as Palo Alto Networks support teams, or ASC (Authorized Support Centers) partners and backline support options. The underlying product used (the VM-Series firewall) by the scripts or templates are still supported, but the support is only for the product functionality and not for help in deploying or using the template or script itself.


