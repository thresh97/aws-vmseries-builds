# vmseries-gwlb-asg-warmpool-3nic-authcodes-aws-secrets


### Overview
This blueprint builds an AWS Autoscaling Group with Warmpool of VM Series NGFW firewalls integrated with a GWLB.  This is a greenfield deployment that is similar to the PAN VM Series Centralized AWS GWLB Reference Architecture with Centralized Egress and E/W Inspection via TGW and Distributed Ingress inspection

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
    - EC2 Instances
    - 2 ec2 web servers
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
- Instance Profile for Launch Template and related policy
- Launch Template for ASG
- Placement Group
- ASG
  - 2 Lifecycle Hooks
  - Autoscaling Policy (Target Tracking)

# parameters
- PAN CSP Licensing Key
- Panorama with public IP (can be A/P)
- Panorama API key
- Panorama vm-auth-key 
- Device Certificate registration PIN ID and Value
- Collector Group Name
- Authcode for VM Series with sufficient capacity to provision at least maximum size of ASG
- public SSH key-pair name in AWS region that ASG will be deployed

## Support Policy
This solution is released under an as-is, best effort, support policy. These scripts should be seen as community supported and Palo Alto Networks will contribute our expertise as and when possible. We do not provide technical support or help in using or troubleshooting the components of the project through our normal support options such as Palo Alto Networks support teams, or ASC (Authorized Support Centers) partners and backline support options. The underlying product used (the VM-Series firewall) by the scripts or templates are still supported, but the support is only for the product functionality and not for help in deploying or using the template or script itself.


