#!/bin/sh -e

## for rdo installed environment
## ovs and dvr configuration

# ovs setting
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-provider.html#deploy-ovs-provider
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-selfservice.html

CONTROLLER_IP={CONTROLLER_IP}
METADATA_PASS={METADATA_PASS}

# compute
#yum -y install openstack-utils
## DO NOT modify
#CONF=/etc/neutron/neutron.conf
#test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
#openstack-config --set ${CONF} DEFAULT core_plugin ml2
#openstack-config --set ${CONF} DEFAULT auth_strategy keystone

CONF=/etc/neutron/plugins/ml2/openvswitch_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} ovs bridge_mappings provider:br-ex
#openstack-config --set ${CONF} securitygroup firewall_driver iptables_hybrid
#openstack-config --set ${CONF} ovs local_ip {{ compute1_tunnel_ip }}
#openstack-config --set ${CONF} ovs local_ip {{ compute2_tunnel_ip }}
openstack-config --set ${CONF} agent tunnel_types vxlan
openstack-config --set ${CONF} agent l2_population True

CONF=/etc/neutron/dhcp_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set ${CONF} DEFAULT enable_isolated_metadata True
openstack-config --set ${CONF} DEFAULT force_metadata True

CONF=/etc/neutron/metadata_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} DEFAULT nova_metadata_ip ${CONTROLLER_IP}
openstack-config --set ${CONF} DEFAULT metadata_proxy_shared_secret ${METADATA_PASS}

# create br-ex bridge and add port eth3
ovs-vsctl list-br |grep br-ex || ovs-vsctl add-br br-ex
ovs-vsctl list-ports br-ex |grep eth3 || ovs-vsctl add-port br-ex eth3

systemctl enable openvswitch
systemctl enable neutron-dhcp-agent
systemctl enable neutron-metadata-agent

systemctl restart openvswitch neutron-dhcp-agent neutron-metadata-agent

# dvr configuration
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-ha-dvr.html
# https://docs.openstack.org/ocata/networking-guide/deploy-ovs-selfservice.html
# https://docs.openstack.org/ocata/networking-guide/config-dvr-ha-snat.html#config-dvr-snat-ha-ovs

#compute
CONF=/etc/neutron/plugins/ml2/openvswitch_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} DEFAULT enable_distributed_routing True
###
openstack-config --set ${CONF} ovs bridge_mappings extnet:br-ex
#openstack-config --set ${CONF} securitygroup firewall_driver iptables_hybrid
openstack-config --set ${CONF} agent arp_responder True

CONF=/etc/neutron/l3_agent.ini
test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org
openstack-config --set ${CONF} DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set ${CONF} DEFAULT external_network_bridge
openstack-config --set ${CONF} DEFAULT agent_mode dvr

systemctl enable neutron-l3-agent
systemctl restart neutron-l3-agent openvswitch neutron-metadata-agent

