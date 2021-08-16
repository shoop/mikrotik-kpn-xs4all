# Example MikroTik configuration for xs4all/KPN

## Assumptions and requirements

- Home use with a limited number of statically allocated wired devices.
- Configured for xs4all/KPN internet provider with IPTV, using
  fiber to the home with GPON, so upstream interface is the SFP+.
- Multiple switch/APs present on different floors of the house,
  managed by CAPsMAN.
- Separate VLAN for wireless guest network.
- Separate VLAN for a stable IPTV setup.
- Dual stack IPv4 and IPV6 ready.
- Provide DHCPv4 service on all VLANs.
- IPv6 configuration using SLAAC.
- Provide home-local DNS service according to RFC 8375.

## Usage
The configuration is in order of /export . Note that re-ordering
may mess with the ability to reload this configuration.

Be sure to replace all parameters, enclosed in << >> .

Reload of the configuration after factory reset:
1. Ensure the ipv6 and multicast packages are installed
2. Upload script to internal router memory
3. /system reset-configuration no-defaults=yes run-after-reset=SCRIPT

This is in use on an RB4011iGS (model without WiFi), two hAP AC^2 and one cAP AC.
