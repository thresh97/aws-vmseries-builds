I have extracted the current content of the Project Documentation from the Canvas. You can copy the Markdown string below:

```markdown
# AWS VM-Series HA Architecture (Single AZ with Rack-Level Spreading)

> **DISCLAIMER: FOR TEST AND DEMO USE ONLY.**
> This code is provided "as is" without warranty of any kind. It is intended for laboratory and demonstration purposes. Before using in a production environment, ensure the architecture is reviewed for security, compliance, and scalability requirements.

## Overview

This Terraform configuration deploys a high-availability pair of Palo Alto Networks VM-Series Firewalls within a **single Availability Zone**. To ensure resilience against hardware failures within that AZ, the firewalls are deployed into an AWS **Placement Group** using the `spread` strategy, ensuring each instance resides on a distinct physical rack.

The architecture is optimized for ENA (Elastic Network Adapter) by using **Secondary Private IP migration** and **API-based Route Table updates** for High Availability (HA) rather than moving entire Network Interfaces.

## Architecture Highlights

### 1. High Availability & Placement

* **Single AZ Deployment:** Simplifies routing and avoids inter-AZ data transfer costs.
* **Rack-Level Spread:** An `aws_placement_group` with `strategy = "spread"` guarantees that FW1 and FW2 are not on the same physical server rack.
* **IAM Policy:** Includes permissions for `AssignPrivateIpAddresses`, `UnassignPrivateIpAddresses`, and `ReplaceRoute`, enabling the VM-Series "AWS Plugin" to manage failover via AWS API calls.

### 2. Network Interface & IP Schema

Each firewall utilizes four interfaces (Management, Untrust, Trust, HA). Subnets are carved from the VPC CIDR using 8-bit offsets.

* **Subnet Assignments:**
  * **Management:** Index 1 (`10.0.1.0/24`)
  * **Untrust:** Index 2 (`10.0.2.0/24`)
  * **Trust:** Index 3 (`10.0.3.0/24`)
  * **Workload:** Index 4 (`10.0.4.0/24`)
  * **HA:** Index 5 (`10.0.5.0/24`)

* **IP Assignment Logic:**
  * **FW1 (Primary):** Assigned **.4** (first usable) in all subnets.
  * **FW2 (Passive):** Assigned **.5** (second usable) in all subnets.
  * **Floating VIP:** The address **.100** is pre-allocated as a secondary IP on FW1's Untrust and Trust interfaces.

### 3. Routing & Traffic Flow

* **Workload Subnet:** The route table for the workload subnet contains a **0.0.0.0/0 route** pointing to the **Trust ENI of FW1** (`eth2`).
* **Security Groups:** Management access is restricted via the `allowed_mgmt_cidrs` variable, while internal subnets allow all traffic within the VPC CIDR.

### 4. HA Failover Mechanism (ENA Compatibility)

Because modern AWS instances (ENA) do not support moving ENIs between running instances, failover is handled by the PAN-OS AWS Plugin:

* **Secondary IP Move:** The new Active firewall detaches the **.100** secondary IP from the failed node and attaches it to its own interfaces.
* **Route Table Update:** The firewall issues a `ReplaceRoute` command to update the Workload Subnet's route table, pointing the **0.0.0.0/0** destination to its own Trust ENI ID.

## PAN-OS HA Configuration (CLI)

### Firewall 1 (Primary)

```bash
set deviceconfig high-availability group 1 peer-ip 10.0.1.5
set deviceconfig high-availability group 1 election-option device-priority 100
set deviceconfig high-availability interface ha1 port management ip-address 10.0.1.4 netmask 255.255.255.0
set deviceconfig high-availability group 1 mode active-passive
set deviceconfig high-availability enabled yes

# AWS Plugin Configuration (for Route and IP moves)
# Replace <workload_rt_id> with the actual AWS Route Table ID from Terraform outputs
set plugins vm_series aws vpc-ha-gateway-mapping trust-table-id <workload_rt_id> trust-interface eth2
set plugins vm_series aws vpc-ha-gateway-mapping untrust-vip 10.0.2.100 untrust-interface eth1

```

### Firewall 2 (Secondary)

```bash
set deviceconfig high-availability group 1 peer-ip 10.0.1.4
set deviceconfig high-availability group 1 election-option device-priority 200
set deviceconfig high-availability interface ha1 port management ip-address 10.0.1.5 netmask 255.255.255.0
set deviceconfig high-availability group 1 mode active-passive
set deviceconfig high-availability enabled yes

# AWS Plugin Configuration
set plugins vm_series aws vpc-ha-gateway-mapping trust-table-id <workload_rt_id> trust-interface eth2
set plugins vm_series aws vpc-ha-gateway-mapping untrust-vip 10.0.2.100 untrust-interface eth1

```

## Finding Available Versions

To find the available VM-Series BYOL AMI versions in your target region:

```bash
aws ec2 describe-images \
    --region us-west-2 \
    --owners aws-marketplace \
    --filters "Name=name,Values=PA-VM-AWS-*" "Name=product-code,Values=6njl1pau431dv1qxipg63mvah" \
    --query 'sort_by(Images, &CreationDate)[].{Name:Name, ImageId:ImageId, Date:CreationDate}' \
    --output table

```

## Deployment Steps

1. **Initialize:** `terraform init`
2. **Review:** `terraform plan -var-file="example.tfvars"`
3. **Deploy:** `terraform apply -var-file="example.tfvars"`

## Outputs

* `fw1_mgmt_ip`: Public IP for FW1 management.
* `fw2_mgmt_ip`: Public IP for FW2 management.
* `untrust_vip_public_ip`: Elastic IP associated with the .100 Untrust Floating VIP.
* `linux_worker_private_ip`: Internal IP of the protected test instance.

```

```
