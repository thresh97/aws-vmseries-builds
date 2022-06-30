# vmseries-gwlb-asg-2nic-pswlp-user-data

### Overview
This blueprint builds an AWS Autoscaling Group of VM Series NGFW firewalls integrated with a GWLB.  This is a greenfield deployment that is similar to the PAN VM Series Centralized AWS GWLB Reference Architecture with Centralized Egress and E/W Inspection via TGW and Distributed Ingress inspection.  It uses User Data for Basic instance meta-data based bootstrapping.  It licenses VM Series with the Panorama Software Licensing Plugin.  This is intended for demo, non-prod, and/or sandbox use.  It is not production grade.

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
- Instance Profile for Launch Template and related policy
- Launch Template for ASG
- Placement Group
- ASG
  - Autoscaling Policy (Target Tracking)

# parameters
- Panorama with public IP (can be A/P)
- Panorama auth-key (Panorama SW Licensing Plugin)
- Device Certificate registration PIN ID and Value
- Collector Group Name
- Template Stack Name
- Device Group Name
- public SSH key-pair name in AWS region that ASG will be deployed

# comments
- hostnames in Panorama are the AWS instance IDs.  This is accomplished by using resource based naming in the launch template and using dhcp-accept-server-hostname=yes in user data.
- this deployment utilizes basic bootstrapping.  No S3 buckets.  No bootstrap.xml.  No init-cfg.txt
- see the scripts/ directory for panorama configuration and commands
- ASG ELB health checks will eventually terminate instances if commit-all from Panorama fails.
- It is helpful to have panxapi.py and aws cli installed and configured
- This deployment will support a maximum of 21 VM series instances.  This is the limitation of spread placement groups.  7 instances per AZ.
- Launches will take about 25 minutes.  

# future
- More testing of Logging (Cortex Data Lake and/or Log Collector)

## Support Policy
This solution is released under an as-is, best effort, support policy. These scripts should be seen as community supported and Palo Alto Networks will contribute our expertise as and when possible. We do not provide technical support or help in using or troubleshooting the components of the project through our normal support options such as Palo Alto Networks support teams, or ASC (Authorized Support Centers) partners and backline support options. The underlying product used (the VM-Series firewall) by the scripts or templates are still supported, but the support is only for the product functionality and not for help in deploying or using the template or script itself.


