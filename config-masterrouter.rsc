# model = RB4011iGS+

#============================================================================
# RB4011iGS+ configuration
#
# Underlying decisions:
# - Home use with a number of statically allocated wired devices.
# - Configured for xs4all/KPN internet provider with IPTV, using
#   fiber to the home with GPON, so upstream interface is the SFP+.
# - Multiple switch/APs present on different floors of the house,
#   managed by CAPsMAN.
# - Separate VLAN for wireless guest network.
# - Separate VLAN for a stable IPTV setup.
# - Dual stack IPv4 and IPV6 ready.
# - Provide DHCPv4 service on all VLANs.
# - IPv6 configuration using SLAAC.
# - Provide home-local DNS service according to RFC 8375.
#
# Potential future expansions:
# - NTP server
# - TFTP server
# - 802.1x RADIUS server (not yet supported by MikroTik)
#
# The configuration below is in order of /export . Note that re-ordering
# may mess with the ability to reload this configuration.
#
# Reload of the configuration after factory reset:
# 1. Ensure the ipv6 and multicast packages are installed
# 2. Upload script to internal router memory
# 3. /system reset-configuration no-defaults=yes run-after-reset=<<SCRIPT>>
#============================================================================

# AP channel definitions.
# Check your area with the snooper tool:
#   /interface wireless snooper
#   https://wiki.mikrotik.com/wiki/Manual:Interface/Wireless#Snooper
/caps-man channel
add band=2ghz-g/n control-channel-width=20mhz extension-channel=disabled \
    frequency=2462 name=f-2462
add band=5ghz-n/ac control-channel-width=20mhz extension-channel=Ceee \
    frequency=5500 name=f-5500

# AP data path definitions.
# Uses local forwarding as home use does not need accounting of all data.
/caps-man datapath
add client-to-client-forwarding=yes local-forwarding=yes name=lan-10 vlan-id=\
    10 vlan-mode=use-tag
add client-to-client-forwarding=no local-forwarding=yes name=guest-30 \
    vlan-id=30 vlan-mode=use-tag

# Add the single bridge interface used for all ports.
# - Recommended is to set a static MAC, especially for CAPsMAN managed
#   interfaces.
# - Ensure that the "CPU" interface is also part of the normal
#   LAN VLAN 10 by setting pvid property.
# - Enable igmp-snooping for IPTV service.
/interface bridge
add admin-mac=<<MAC-OF-FIRST-PORT>> auto-mac=no fast-forward=no igmp-snooping=yes \
    name=bridge-lan pvid=10 vlan-filtering=yes

# Do not enable auto-negotiation. The RB4011 software v6.47.10 has a bug
# where the interface shows that it is connected, however no packets are
# actually sent out. See (Dutch):
#   https://gathering.tweakers.net/forum/list_message/67936436#67936436
# The MTU is set because of the ISP PPPoE requirements.
/interface ethernet
set [ find default-name=sfp-sfpplus1 ] arp=reply-only auto-negotiation=no \
    l2mtu=1596 loop-protect=off mtu=1512 speed=1Gbps

# Add the three different internal VLANs
/interface vlan
add interface=bridge-lan name=guest-30 vlan-id=30
add interface=bridge-lan name=iptv-20 vlan-id=20
add interface=bridge-lan name=lan-10 vlan-id=10

# Add the ISP mandated VLANs as coming in on the fiber line.
add interface=sfp-sfpplus1 name=xs4all-iptv-4 vlan-id=4
add interface=sfp-sfpplus1 loop-protect=off name=xs4all-wan-6 vlan-id=6

# AP rate definition.
/caps-man rates
add basic=6Mbps,12Mbps,24Mbps name=rate1 supported=\
    6Mbps,9Mbps,12Mbps,18Mbps,24Mbps,36Mbps,48Mbps,54Mbps

# AP security definitions.
/caps-man security
add authentication-types=wpa2-psk encryption=aes-ccm group-encryption=aes-ccm \
    name=<<SSID>> passphrase=<<PASSPHRASE>>
add authentication-types=wpa2-psk encryption=aes-ccm group-encryption=aes-ccm \
    name=<<GUESTSSID>> passphrase=<<GUESTPASSPHRASE>>

# AP configurations.
# Note that CAPsMAN configurations are layered, so the configuration for the
# guest network only specifies the properties to change relative to both of
# the base network configurations.
/caps-man configuration
add channel=f-2462 country=netherlands datapath=lan-10 distance=indoors \
    hw-retries=3 installation=indoor mode=ap multicast-helper=full name=\
    conf-2ghz rates=rate1 security=<<SSID>> ssid=<<SSID>>
add datapath=guest-30 name=conf-guest rates=rate1 security=<<GUESTSSID>> ssid=\
    <<GUESTSSID>>
add channel=f-5500 country=netherlands datapath=lan-10 distance=indoors \
    hw-retries=3 installation=indoor mode=ap multicast-helper=full name=\
    conf-5ghz rates=rate1 security=<<SSID>> ssid=<<SSID>>

# Switch port definitions.
# This is related to the older MikroTik VLAN definitions. It is not necessary
# when using Bridge VLAN configuration as we do, however these settings
# always appear in exports.
/interface ethernet switch port
set 0 default-vlan-id=0
set 1 default-vlan-id=0
set 2 default-vlan-id=0
set 3 default-vlan-id=0
set 4 default-vlan-id=0
set 5 default-vlan-id=0
set 6 default-vlan-id=0
set 7 default-vlan-id=0
set 8 default-vlan-id=0
set 9 default-vlan-id=0
set 10 default-vlan-id=0
set 11 default-vlan-id=0

# Add different lists for the interfaces to be able to set up firewall rules.
/interface list
add name=WAN
add name=LAN
add name=GUEST

# Set this routers wireless interface identity.
# This line is always present in exports, but has no effect as the RB4011iGS
# does not have any wireless interfaces.
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik

# Add DHCP client and server options necessary for the STB.
/ip dhcp-client option
add code=60 name=option60-vendorclass value="'IPTV_RG'"
/ip dhcp-server option
add code=60 name=option60-vendorclass value="'IPTV_RG'"
add code=28 name=option28-broadcast value="'192.168.20.255'"

# Add DHCP server option for the trusted LAN. Conforms to RFC 8375.
# Note that the binary prefixes correspond to the length of the
# string following, adjust if needed.
add code=119 name=option119-domainsearch value=\
    "0x07'example'0x04'home'0x04'arpa'0x00"

# Combine the options for the STB into an option set for easy reference.
/ip dhcp-server option sets
add name=IPTV options=option60-vendorclass,option28-broadcast

# Define DHCP server IP pools for each VLAN.
/ip pool
add name=dhcp-lan-10 ranges=192.168.10.50-192.168.10.199
add name=dhcp-iptv-20 ranges=192.168.20.50-192.168.20.199
add name=dhcp-guest-30 ranges=192.168.30.50-192.168.30.199

# Setup DHCP server for each VLAN.
# Note that technically the IPTV VLAN could have been setup
# as a static-only server. For testing purposes it is easier
# to also be able to connect a laptop and check connectivity.
/ip dhcp-server
add address-pool=dhcp-lan-10 disabled=no interface=lan-10 name=\
    dhcp-server-lan-10
add address-pool=dhcp-iptv-20 disabled=no interface=iptv-20 name=\
    dhcp-server-iptv-20
add address-pool=dhcp-guest-30 disabled=no interface=guest-30 name=\
    dhcp-server-guest-30

# Add IPv6 DHCP server options to ensure that the router is advertised
# as the DNS server, and that IPv6 only devices also get the correct
# DNS search domain. Note that this implies the setup of a unique ULA,
# below in the IPv6 pool definition.
/ipv6 dhcp-server option
add code=23 name=option23-dnsserver value="'<<ULA-PREFIX>>::1'"
add code=24 name=option24-domainsearch value=\
    "0x07'example'0x04'home'0x04'arpa'0x00"

# Setup a unique local address for IPv6, as per the following blog post:
#   https://blog.apnic.net/2020/05/20/getting-ipv6-private-addressing-right/
# Generated using
#   https://www.ip-six.de/
/ipv6 pool
add name=ula-pool prefix=<<ULA-PREFIX>>::/64 prefix-length=64

# Set the PPP profile used by the PPPoE client to also use IPv6.
/ppp profile
set *0 only-one=yes use-compression=yes use-ipv6=no use-upnp=no
add name=default-ipv6 only-one=yes use-compression=yes use-upnp=no

# xs4all/KPN configuration to request WAN connectivity using PPPoE
# on VLAN 6 on the fiber interface. All WAN traffic is tunneled
# using this PPPoE connection.
/interface pppoe-client
add add-default-route=yes allow=pap disabled=no interface=xs4all-wan-6 \
    keepalive-timeout=20 max-mru=1500 max-mtu=1500 name=\
    xs4all-wan-pppoe-client password=internet profile=default-ipv6 \
    use-peer-dns=yes user=internet

# Disable BGP routing.
/routing bgp instance
set default disabled=yes

# AP client access list.
# These rules ensure that clients switch to another AP if the signal is
# too weak.
/caps-man access-list
add action=accept allow-signal-out-of-range=10s disabled=no interface=any \
    signal-range=-85..-10 ssid-regexp=""
add action=reject allow-signal-out-of-range=10s disabled=no interface=any \
    signal-range=-120..-86 ssid-regexp=""

# Enable CAPsMAN management of APs.
/caps-man manager
set enabled=yes

# Provision the APs around the house.
# Repeat the two rules for every AP using the wlan1/wlan2 MAC addresses.
/caps-man provisioning
add action=create-dynamic-enabled master-configuration=conf-2ghz radio-mac=\
    <<AP1-WLAN1-MAC>> slave-configurations=conf-guest
add action=create-dynamic-enabled master-configuration=conf-5ghz radio-mac=\
    <<AP1-WLAN2-MAC>> slave-configurations=conf-guest

# Add the bridge ports with VLAN configuration.
# First three Ethernet ports are TRUNK ports where the APs are connected.
# The last Ethernet port (10) connects the STB for IPTV.
# The rest is part of the regular LAN.
# Note that we could have chosen to use untagged VLAN for the normal LAN
# as trunk port security cannot be guaranteed in a normal home. However
# this makes it harder to provide e.g. DHCP services from the router so
# we go for tagged traffic up until each access port.
/interface bridge port
add bridge=bridge-lan comment=TRUNK frame-types=admit-only-vlan-tagged \
    ingress-filtering=yes interface=ether1
add bridge=bridge-lan comment=TRUNK frame-types=admit-only-vlan-tagged \
    ingress-filtering=yes interface=ether2
add bridge=bridge-lan comment=TRUNK frame-types=admit-only-vlan-tagged \
    ingress-filtering=yes interface=ether3
add bridge=bridge-lan comment=LAN interface=ether4 pvid=10
add bridge=bridge-lan comment=LAN interface=ether5 pvid=10
add bridge=bridge-lan comment=LAN interface=ether6 pvid=10
add bridge=bridge-lan comment=LAN interface=ether7 pvid=10
add bridge=bridge-lan comment=LAN interface=ether8 pvid=10
add bridge=bridge-lan comment=LAN interface=ether9 pvid=10
add bridge=bridge-lan comment=IPTV interface=ether10 pvid=20

# Allow discovery. The security risks in a home environment are minimal.
# Due to the use of the LAN list, the GUEST network is excluded.
/ip neighbor discovery-settings
set discover-interface-list=LAN

# Set bridge trunk/access port configuration. Ensure that the bridge-lan
# interface itself is part of the tagged list so that services such as
# DHCP can run per VLAN.
/interface bridge vlan
add bridge=bridge-lan tagged=bridge-lan,ether1,ether2,ether3 untagged=\
    ether4,ether5,ether6,ether7,ether8,ether9 vlan-ids=10
add bridge=bridge-lan tagged=bridge-lan,ether1,ether2,ether3 untagged=ether10 \
    vlan-ids=20
add bridge=bridge-lan tagged=bridge-lan,ether1,ether2,ether3 vlan-ids=30

# Add the correct interfaces to each list, for security.
# Note that IPTV is combined with LAN, for simplicities sake. For a home
# environment, the STB is not anymore dangerous than any other device.
/interface list member
add interface=sfp-sfpplus1 list=WAN
add interface=lan-10 list=LAN
add interface=iptv-20 list=LAN
add interface=guest-30 list=GUEST

# Add gateway IP addresses per VLAN.
/ip address
add address=192.168.10.1/24 comment=LAN interface=lan-10 network=192.168.10.0
add address=192.168.20.1/24 comment=IPTV interface=iptv-20 network=\
    192.168.20.0
add address=192.168.30.1/24 comment=GUEST interface=guest-30 network=\
    192.168.30.0

# Set the IPTV DHCP client as per xs4all/KPN ISP requirements.
# The routes provided by the DHCP offer should be ignored, hence the high
# default route distance.
/ip dhcp-client
add default-route-distance=210 dhcp-options=option60-vendorclass disabled=no \
    interface=xs4all-iptv-4 use-peer-dns=no use-peer-ntp=no

# Add static DHCP server leases for the wired connected devices in the home.
# This is a preference, there is no real need to do so.
/ip dhcp-server lease
add address=192.168.20.20 comment=stb.example.home.arpa mac-address=\
    <<MAC-OF-STB>> server=dhcp-server-iptv-20
add address=192.168.10.20 comment=fixed.example.home.arpa mac-address=\
    <<MAC-OF-FIXED-SERVICE>> server=dhcp-server-lan-10

# Add a DHCP server for each VLAN. Note that this requires that the
# traffic generated from the router itself is tagged by including the
# bridge interface in the list of tagged ports.
# Note that the IPTV VLAN will be using the upstream DNS servers directly.
# The GUEST VLAN will be using Google/Cloudflare DNS servers directly.
/ip dhcp-server network
add address=192.168.10.0/24 comment=lan-10 dhcp-option=option119-domainsearch \
    dns-server=192.168.10.1 gateway=192.168.10.1
add address=192.168.20.0/24 comment=iptv-20 dns-server=\
    194.109.6.66,194.109.9.99 gateway=192.168.20.1
add address=192.168.30.0/24 comment=guest-30 dns-server=8.8.8.8,1.1.1.1 \
    gateway=192.168.30.1

# Set up DNS service for the home LAN, using the upstream servers.
/ip dns
set allow-remote-requests=yes cache-max-ttl=1d servers=\
    194.109.6.66,194.109.9.99,2001:888:0:6::66,2001:888:0:9::99

# Add static DNS entries.
# Just like static DHCP leases, this is not entirely necessary,
# rather just convenient.
/ip dns static
add address=192.168.10.20 name=fixed.example.home.arpa
add address=192.168.20.20 name=stb.example.home.arpa

# IPv4 firewall rules.
# Based on the default rules, with the addition of IPTV and SSH
# service rules.
/ip firewall filter
add action=fasttrack-connection chain=forward comment="DEF: fasttrack" \
    connection-state=established,related
add action=accept chain=input comment=\
    "DEF: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=accept chain=forward comment=\
    "DEF: accept established,related, untracked" connection-state=\
    established,related,untracked
add action=accept chain=input comment="DEF: accept ICMP" protocol=icmp

# IPTV requires IGMP and UDP traffic.
# TODO: the forward rule is now rather broad, due to a lot of
#       experimenting and failures with the STB. It can probably
#       be narrowed.
add action=accept chain=input comment="IPTV Multicast" dst-address=\
    224.0.0.0/8 in-interface=xs4all-iptv-4 protocol=igmp
add action=accept chain=input comment="IPTV Multicast" dst-address=\
    224.0.0.0/8 in-interface=xs4all-iptv-4 protocol=udp
add action=accept chain=forward comment="IPTV traffic" in-interface=\
    xs4all-iptv-4

add action=drop chain=input comment="DEF: drop invalid" connection-state=\
    invalid

# TODO: this rule is only necessary for devices with wireless capability,
#       so that CAPsMAN can manage the device itself. It does not hurt,
#       but should probably be removed.
add action=accept chain=input comment=\
    "DEF: accept to local loopback (for CAPsMAN)" dst-address=127.0.0.1

# Allow SSH access on the non-standard port, from the LAN.
# Using static DHCP/IP entries this can be limited even more, but once
# an attacker is in the LAN network and able to probe user/pass there
# are bigger problems.
add action=accept chain=input comment="Allow SSH to MikroTik from LAN" \
    dst-address=192.168.10.1 dst-port=2222 in-interface-list=LAN protocol=tcp

add action=drop chain=input comment="DEF: drop all not coming from LAN" \
    in-interface-list=!LAN log=yes

# TODO: these next two IPSEC policy rules are default. Not sure why, and
#       whether they are needed.
add action=accept chain=forward comment="DEF: accept in ipsec policy" \
    ipsec-policy=in,ipsec
add action=accept chain=forward comment="DEF: accept out ipsec policy" \
    ipsec-policy=out,ipsec

add action=drop chain=forward comment="DEF: drop invalid" connection-state=\
    invalid
add action=drop chain=forward comment="DEF: drop all from WAN not DSTNATed" \
    connection-nat-state=!dstnat connection-state=new in-interface-list=WAN \
    log=yes

# Ensure WAN traffic is correctly NATted.
/ip firewall nat
add action=masquerade chain=srcnat comment="IPTV masquerade" out-interface=\
    xs4all-iptv-4
add action=masquerade chain=srcnat comment="WAN masquerade" ipsec-policy=\
    out,none out-interface=xs4all-wan-pppoe-client

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

# Ensure UPnP is disabled.
/ip upnp
set enabled=no

# Add IPv6 address as assigned by ISP. This will be requested using DHCPv6.
/ipv6 address
add address=::1 from-pool=ISP interface=lan-10

# Add IPv6 address from the ULA pool defined above.
add address=<<ULA-PREFIX>>::1 comment="IPv6 ULA address" interface=lan-10

# Setup DHCPv6 request on established PPPoE connection from ISP.
/ipv6 dhcp-client
add add-default-route=yes interface=xs4all-wan-pppoe-client pool-name=ISP \
    pool-prefix-length=48 request=prefix use-peer-dns=no

# Add a stateless DHCPv6 server that will respond with IPv6 address of
# DNS server, and the correct domain search option.
/ipv6 dhcp-server
add dhcp-option=option23-dnsserver,option24-domainsearch interface=lan-10 \
    name=ipv6-dns-advertisement

# Add default IPv6 firewall.
/ipv6 firewall address-list
add address=::/128 comment="defconf: unspecified address" list=bad_ipv6
add address=::1/128 comment="defconf: lo" list=bad_ipv6
add address=fec0::/10 comment="defconf: site-local" list=bad_ipv6
add address=::ffff:0.0.0.0/96 comment="defconf: ipv4-mapped" list=bad_ipv6
add address=::/96 comment="defconf: ipv4 compat" list=bad_ipv6
add address=100::/64 comment="defconf: discard only " list=bad_ipv6
add address=2001:db8::/32 comment="defconf: documentation" list=bad_ipv6
add address=2001:10::/28 comment="defconf: ORCHID" list=bad_ipv6
add address=3ffe::/16 comment="defconf: 6bone" list=bad_ipv6
add address=::224.0.0.0/100 comment="defconf: other" list=bad_ipv6
add address=::127.0.0.0/104 comment="defconf: other" list=bad_ipv6
add address=::/104 comment="defconf: other" list=bad_ipv6
add address=::255.0.0.0/104 comment="defconf: other" list=bad_ipv6
/ipv6 firewall filter
add action=accept chain=input comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=input comment="defconf: drop invalid" connection-state=\
    invalid
add action=accept chain=input comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=input comment="defconf: accept UDP traceroute" port=\
    33434-33534 protocol=udp
add action=accept chain=input comment=\
    "defconf: accept DHCPv6-Client prefix delegation." dst-port=546 protocol=\
    udp src-address=fe80::/10
add action=accept chain=input comment="defconf: accept IKE" dst-port=500,4500 \
    protocol=udp
add action=accept chain=input comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=input comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=input comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=input comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN
add action=accept chain=forward comment=\
    "defconf: accept established,related,untracked" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="defconf: drop invalid" \
    connection-state=invalid
add action=drop chain=forward comment=\
    "defconf: drop packets with bad src ipv6" src-address-list=bad_ipv6
add action=drop chain=forward comment=\
    "defconf: drop packets with bad dst ipv6" dst-address-list=bad_ipv6
add action=drop chain=forward comment="defconf: rfc4890 drop hop-limit=1" \
    hop-limit=equal:1 protocol=icmpv6
add action=accept chain=forward comment="defconf: accept ICMPv6" protocol=\
    icmpv6
add action=accept chain=forward comment="defconf: accept HIP" protocol=139
add action=accept chain=forward comment="defconf: accept IKE" dst-port=\
    500,4500 protocol=udp
add action=accept chain=forward comment="defconf: accept ipsec AH" protocol=\
    ipsec-ah
add action=accept chain=forward comment="defconf: accept ipsec ESP" protocol=\
    ipsec-esp
add action=accept chain=forward comment=\
    "defconf: accept all that matches ipsec policy" ipsec-policy=in,ipsec
add action=drop chain=forward comment=\
    "defconf: drop everything else not coming from LAN" in-interface-list=\
    !LAN

# Setup IPv6 SLAAC on the LAN VLAN. The DNS server and domain search list
# will be requested by clients using DHCPv6 because of the other-configuration
# setting.
/ipv6 nd
set [ find default=yes ] disabled=yes
add advertise-dns=no advertise-mac-address=no hop-limit=64 interface=lan-10 \
    other-configuration=yes

# Set IGMP proxy for the IPTV subnet. Quick leave is on as currently there is
# only one STB connected.
/routing igmp-proxy
set quick-leave=yes

# Set the IGMP proxy upstream and downstream interfaces.
# TODO: test whether we can use 0.0.0.0/0 as alternative-subnets. The explicit
#       xs4all/KPN IP ranges are set due to a lot of experimenting and failures
#       with the STB.
/routing igmp-proxy interface
add alternative-subnets=217.166.0.0/16,213.75.0.0/16,10.29.0.0/18 interface=\
    xs4all-iptv-4 upstream=yes
add interface=iptv-20

# Set the time zone. This is actually automatically set by the default
# /ip cloud set update-time=yes setting, however it appears in the export.
/system clock
set time-zone-name=Europe/Amsterdam

# Set the system short hostname.
/system identity
set name=<<ROUTERNAME>>

# Disable the bandwith-server tool for security.
/tool bandwidth-server
set enabled=no

# Allow Winbox connections from the LAN VLAN.
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN

# Follow LTS package.
/system package update
set channel=long-term
