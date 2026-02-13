allowed_mgmt_cidrs=["192.0.2.0/24"]
ssh_key_name="your-ssh-key-name"
panos_version="12.1.4"
# --------------------------------------------------------------------------
# General Configuration
# --------------------------------------------------------------------------
#prefix   = "aws-vmseries-ha"
region   = "us-west-2"

# --------------------------------------------------------------------------
# Instance Configuration
# --------------------------------------------------------------------------

vmseries_bootstrap_custom_1 = <<EOT
authcodes=YOUR_AUTH_CODE
panorama-server=cloud
plugin-op-commands=advance-routing:enable,set-cores:2
vm-series-auto-registration-pin-id=00000000-0000-0000-0000-000000000000
vm-series-auto-registration-pin-value=00000000000000000000000000000000
dgname=aws_ha
dhcp-send-hostname=yes
dhcp-send-client-id=yes
dhcp-accept-server-hostname=yes
dhcp-accept-server-domain=yes
EOT

vmseries_bootstrap_custom_2 = <<EOT
authcodes=YOUR_AUTH_CODE
panorama-server=cloud
plugin-op-commands=advance-routing:enable,set-cores:2
vm-series-auto-registration-pin-id=00000000-0000-0000-0000-000000000000
vm-series-auto-registration-pin-value=00000000000000000000000000000000
dgname=aws_ha
dhcp-send-hostname=yes
dhcp-send-client-id=yes
dhcp-accept-server-hostname=yes
dhcp-accept-server-domain=yes
EOT
