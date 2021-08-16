# model = RBD52G-5HacD2HnD

#============================================================================
# Switch/AP configuration for hAP^2.
#
# Requires CAPsMAN on the master router. See also the RB4011iGS
# configuration for underlying decisions.
#============================================================================

# Add the single bridge interface used for all ports.
# - Recommended is to set a static MAC, especially for CAPsMAN managed
#   interfaces.
# - Ensure that the "CPU" interface is also part of the normal
#   LAN VLAN 10 by setting pvid property.
/interface bridge
add admin-mac=<<MAC-OF-FIRST-PORT>> auto-mac=no name=bridge-lan pvid=10 \
    vlan-filtering=yes

# The wireless interfaces are managed by CAPsMAN, however they always
# appear in the export as well.
/interface wireless
set [ find default-name=wlan1 ] disabled=no ssid=MikroTik
set [ find default-name=wlan2 ] disabled=no ssid=MikroTik

# Define the necessary VLANs.
/interface vlan
add interface=bridge-lan name=guest-30 vlan-id=30
add interface=bridge-lan name=iptv-20 vlan-id=20
add interface=bridge-lan name=lan-10 vlan-id=10

# Define two interface lists for security.
/interface list
add name=LAN
add name=GUEST

# Set this APs wireless interface identity.
# Currently unused, but automatically exported.
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik

# Set default hotspot HTML directory.
# Currently unused, but automatically exported.
/ip hotspot profile
set [ find default=yes ] html-directory=flash/hotspot

# Add the bridge ports with VLAN configuration.
# The first Ethernet ports is the TRUNK ports connected to the master
# router.
# CAPsMAN managed wlan interfaces will automatically be added to the
# correct bridge ports conforming to the datapath configuration.
/interface bridge port
add bridge=bridge-lan comment=TRUNK frame-types=admit-only-vlan-tagged \
    ingress-filtering=yes interface=ether1 pvid=10
add bridge=bridge-lan comment=LAN interface=ether2 pvid=10
add bridge=bridge-lan comment=LAN interface=ether3 pvid=10
add bridge=bridge-lan comment=LAN interface=ether4 pvid=10
add bridge=bridge-lan comment=LAN interface=ether5 pvid=10

# Allow router discovery over the normal LAN.
/ip neighbor discovery-settings
set discover-interface-list=LAN

# Accept IPv6 router advertisements. This will grant the router itself
# an IPv6 address and default route, and will then allow clients to
# use IPv6 to connect.
#
# However, due to a bug in RouterOS 6.47.10 this address and route
# are NOT visible in the /ipv6 address and /ipv6 route settings.
# Test with:
#    /ping [:resolve ipv6.google.com]
# Hopefully this gets fixed in RouterOS 7.
# See
#    https://forum.mikrotik.com/viewtopic.php?t=162802
/ipv6 settings
set accept-router-advertisements=yes

# Set bridge trunk/access port configuration. Ensure that the bridge-lan
# interface itself is part of the tagged list, required to use services
# on the VLAN such as DHCP.
/interface bridge vlan
add bridge=bridge-lan tagged=bridge-lan,ether1 untagged=\
    ether2,ether3,ether4,ether5 vlan-ids=10
add bridge=bridge-lan tagged=bridge-lan,ether1 vlan-ids=20
add bridge=bridge-lan tagged=bridge-lan,ether1 vlan-ids=30

# Add the correct interfaces to each list, for security.
# Note that IPTV is combined with LAN, for simplicities sake. For a home
# environment, the STB is not anymore dangerous than any other device.
/interface list member
add interface=lan-10 list=LAN
add interface=iptv-20 list=LAN
add interface=guest-30 list=GUEST

# Set CAPsMAN management link, auto discovery on the LAN network.
/interface wireless cap
set bridge=bridge-lan discovery-interfaces=lan-10 enabled=yes interfaces=\
    wlan1,wlan2

# Configure static IP address, DNS and route for the switch/AP itself.
# Necessary for correct time keeping and checking for system updates.
/ip address
add address=192.168.10.<<ADDRESS>>/24 interface=lan-10 network=192.168.10.0
/ip dns
set servers=192.168.10.1
/ip route
add distance=1 gateway=192.168.10.1

# Disable unnecessary services. Set SSH to port 2222 to avoid conflict
# with port 22 on the outside.
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh address=192.168.10.0/24 port=2222
set api disabled=yes
set winbox disabled=yes
set api-ssl disabled=yes

# Enable better SSH crypto.
/ip ssh
set strong-crypto=yes

# Disable IPv6 advertising as this is done from the master router.
/ipv6 nd
set [ find default=yes ] disabled=yes

# Set the time zone. This is actually automatically set by the default
# /ip cloud set update-time=yes setting, however it appears in the export.
/system clock
set time-zone-name=Europe/Amsterdam

# Set the system short hostname.
/system identity
set name=<<ROUTERNAME>>

# Follow LTS package.
/system package update
set channel=long-term
