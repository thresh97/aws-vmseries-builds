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
set network interface ethernet ethernet1/1 ha
set deviceconfig system hostname aws-ha-fw1
set deviceconfig high-availability interface ha1 port management
set deviceconfig high-availability interface ha2 ip-address 10.0.4.4
set deviceconfig high-availability interface ha2 netmask 255.255.255.0
set deviceconfig high-availability interface ha2 gateway 10.0.4.1
set deviceconfig high-availability interface ha2 port ethernet1/1
set deviceconfig high-availability group mode active-passive 
set deviceconfig high-availability group group-id 63
set deviceconfig high-availability group peer-ip 10.0.1.5
set deviceconfig high-availability group state-synchronization enabled yes
set deviceconfig high-availability group state-synchronization transport udp
set deviceconfig high-availability group election-option device-priority 100
set deviceconfig high-availability enabled yes
set deviceconfig setting advance-routing yes
```

### Firewall 2 (Secondary)

```bash
set network interface ethernet ethernet1/1 ha
set deviceconfig system hostname aws-ha-fw2
set deviceconfig high-availability interface ha1 port management
set deviceconfig high-availability interface ha2 ip-address 10.0.4.5
set deviceconfig high-availability interface ha2 netmask 255.255.255.0
set deviceconfig high-availability interface ha2 gateway 10.0.4.1
set deviceconfig high-availability interface ha2 port ethernet1/1
set deviceconfig high-availability group mode active-passive 
set deviceconfig high-availability group group-id 63
set deviceconfig high-availability group peer-ip 10.0.1.4
set deviceconfig high-availability group state-synchronization enabled yes
set deviceconfig high-availability group state-synchronization transport udp
set deviceconfig high-availability group election-option device-priority 101
set deviceconfig high-availability enabled yes
set deviceconfig setting advance-routing yes
```

### Configure Secondary IP High Availability

```bash
request plugins vm_series aws ha failover-mode secondary-ip
```

### Verify Secondary IP High Availability

```bash
show plugins vm_series aws ha ips
```

## SCM Folder Configuration**

After successfully committing to your SCM Folder, ensure the following network and policy objects are configured to match the live state of the hub firewalls.

**Important Note on HA (SCM 2025.r5.0):** High Availability (HA) must NOT be configured or managed within the SCM Folder as of version 2025.r5.0. This deployment utilizes the Management port for HA1 control traffic, a configuration that is currently not supported in the SCM workflow. HA settings must remain as local device configuration and should be excluded from SCM-pushed templates.

### **Network Interfaces & Zones**

Map the hardware interfaces to the logical zones and virtual routers.

| Interface | Type | IPv4 Address(es) | Zone | Forwarding |
| :---- | :---- | :---- | :---- | :---- |
| ethernet1/3 | Layer3 | 10.0.2.100/24, 10.0.2.4/32, 10.0.2.5/32 | internet | lr:default |
| ethernet1/2 | Layer3 | 10.0.3.100/24, 10.0.3.4/32, 10.0.3.5/32 | local | lr:default |

### **NAT Policy**

Configure the SNAT policy to ensure outbound traffic uses the **Floating VIP** for consistent identity during failover.

**Policy Name:** SNAT Egress

* **Source Zone:** local  
* **Destination Zone:** internet  
* **Destination Interface:** ethernet1/1  
* **Service:** any  
* **Source Translation:** Dynamic IP and Port  
* **Translated Address:** Interface Address \-\> ethernet1/1 \-\> 10.0.2.100

### **Routing (Virtual Router: default)**

* **Default Route (0.0.0.0/0):** Interface ethernet1/3, Next Hop IP Address (Azure Subnet Gateway: 10.0.2.1).  
* **RFC1918 (Private) Routes:** Interface ethernet1/2, Next Hop IP Address (Azure Subnet Gateway: 10.0.3.1).


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
