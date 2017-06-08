#!/bin/sh -e

## for rdo installed environment
## ovs and dvr configuration

# ovs setting
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-provider.html#deploy-ovs-provider
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-selfservice.html

# controller
CONF=/etc/neutron/neutron.conf
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
#openstack-config --set ${CONF} DEFAULT core_plugin ml2 ## DO NOT modify
openstack-config --set ${CONF} DEFAULT auth_strategy keystone
openstack-config --set ${CONF} DEFAULT dhcp_agents_per_network 2
openstack-config --set ${CONF} DEFAULT allow_overlapping_ips True

CONF=/etc/neutron/plugins/ml2/ml2_conf.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} ml2 type_drivers flat,vxlan
openstack-config --set ${CONF} ml2 tenant_network_types vxlan
openstack-config --set ${CONF} ml2 mechanism_drivers openvswitch,l2population
openstack-config --set ${CONF} ml2 extension_drivers port_security
# openstack-config --set ${CONF} ml2_type_flat flat_networks provider
# openstack-config --set ${CONF} ml2_type_flat network_vlan_ranges provider
openstack-config --set ${CONF} ml2_type_vxlan vni_ranges 10:100

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

systemctl stop neutron-dhcp-agent
systemctl stop neutron-metadata-agent
systemctl disable neutron-dhcp-agent
systemctl disable neutron-metadata-agent

## network
## controller and network node are on the same node
CONF=/etc/neutron/neutron.conf
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
#openstack-config --set ${CONF} DEFAULT core_plugin ml2
openstack-config --set ${CONF} DEFAULT auth_strategy keystone

CONF=/etc/neutron/plugins/ml2/openvswitch_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} ovs bridge_mappings extnet:br-ex
#openstack-config --set ${CONF} ovs local_ip {{ controller_tunnel_ip }}
openstack-config --set ${CONF} agent tunnel_types vxlan
openstack-config --set ${CONF} agent l2_population True
#openstack-config --set ${CONF} securitygroup firewall_driver iptables_hybrid

CONF=/etc/neutron/l3_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
#openstack-config --set ${CONF} DEFAULT interface_driver openvswitch
#  Note: The external_network_bridge option intentionally contains no value.
openstack-config --set ${CONF} DEFAULT external_network_bridge

systemctl restart neutron-server neutron-l3-agent openvswitch

## dvr configuration
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-ha-dvr.html
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-selfservice.html
# https://docs.openstack.org/ocata/networking-guide/config-dvr-ha-snat.html#config-dvr-snat-ha-ovs

# controller
CONF=/etc/neutron/neutron.conf
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} DEFAULT router_distributed True

systemctl restart neutron-server

# network
CONF=/etc/neutron/plugins/ml2/openvswitch_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} DEFAULT enable_distributed_routing True
openstack-config --set ${CONF} agent arp_responder True

CONF=/etc/neutron/l3_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} DEFAULT agent_mode dvr_snat

systemctl restart neutron-l3-agent openvswitch

