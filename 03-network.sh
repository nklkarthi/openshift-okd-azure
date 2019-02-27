#!/bin/bash
source 00-configuration.sh

# ------------------------------------------------------------------------------
# Security Group containing OKD ports
# 
# Network Security Groups (NSGs) provide a list of rules to either allow or
# deny traffic to resources deployed within an Azure Virtual Network. NSGs use
# numeric priority values and rules to define what items are allowed to
# communicate with each other. You can place restrictions on where
# communication is allowed to occur, such as within only the virtual network,
# from load balancers, or from everywhere. Priority values allow for
# administrators to grant granular values on the order in which port
# communication is allowed or not allowed to occur.
az network nsg create \
	--name ${DMZ_NSG_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION}

# Allow SSH into DMZ subnet
az network nsg rule create \
	--name nsg-rule-dmz-ssh \
	--nsg-name ${DMZ_NSG_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--priority 1000 \
	--access Allow \
	--direction Inbound \
	--destination-port-ranges "22" \
	--description "Allow SSH"

az network nsg create \
	--name ${PRIVATE_NSG_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION}

# Allow HTTPS into private subnet
az network nsg rule create \
	--name nsg-rule-private-https \
	--nsg-name ${PRIVATE_NSG_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--priority 1000 \
	--access Allow \
	--direction Inbound \
	--destination-port-ranges "443" \
	--description "Allow HTTPS"

# ------------------------------------------------------------------------------
# Azure Virtual Network used to isolate Azure cloud networks from one another.
# Instances and load balancers use the virtual network to allow communication
# with each other and to and from the Internet. The virtual network allows for
# the creation of one or many subnets to be used by components within a
# resource group. You can also connect virtual networks to various VPN
# services, allowing communication with on-premise services.
az network vnet create \
	--name ${VNET_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION}

az network vnet subnet create \
	--name ${DMZ_SUBNET_NAME} \
	--vnet-name ${VNET_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--network-security-group ${DMZ_NSG_NAME} \
	--address-prefix ${DMZ_SUBNET_CIDR}

az network vnet subnet create \
	--name ${PRIVATE_SUBNET_NAME} \
	--vnet-name ${VNET_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--network-security-group ${PRIVATE_NSG_NAME} \
	--address-prefix ${PRIVATE_SUBNET_CIDR}

# ------------------------------------------------------------------------------
# DNS entries for routers and OKD web console
# #
# Azure DNS offers a managed DNS service that provides internal and Internet-
# accessible host name and load balancer resolution. The reference environment
# uses a DNS zone to host three DNS A records to allow for mapping of public
# IPs to OpenShift resources and a bastion host.
# #
# Private DNS Zones provide name resolution within a virtual network as well
# as between virtual networks. If you specify a registration virtual network,
# the DNS records for the VMs from that virtual network that are registered to
# the private zone are not viewable or retrievable from the Azure Powershell
# and Azure CLI APIs, but the VM records are indeed registered and will
# resolve successfully. The virtual machines are registered (added) to the
# private zone as A records pointing to their private IPs. When a virtual
# machine in a registration virtual network is deleted, Azure also
# automatically removes the corresponding DNS record from the linked private
# zone.
az network dns zone create \
	--name ${INTERNAL_DNS_ZONE} \
	--resource-group ${OPENSHIFT_RG} \
	--zone-type Private \
	--registration-vnets ${VNET_NAME}


# ------------------------------------------------------------------------------
# Two Load Balancers allow network connectivity for scaling and high
# availability of services running on virtual machines within the Azure
# environment.

# Master LB (to Master nodes)
az network lb create \
	--name okd-${CLUSTER_NAME}-master-lb \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION} \
	--sku Basic \
	--public-ip-address-allocation static \
	--public-ip-address okd-${CLUSTER_NAME}-master-lb-ip \
	--vnet-name ${VNET_NAME} \
	--frontend-ip-name master-lb-frontend-pool \
	--backend-pool-name master-lb-backend-pool

# Health Probe for HTTPS Traffic to the Master LB (Admin Console)
az network lb probe create \
	--resource-group  ${OPENSHIFT_RG} \
	--lb-name okd-${CLUSTER_NAME}-master-lb \
	--name master-lb-https-probe \
	--protocol tcp \
	--port 443

# LB Rule HTTPS Traffic to the Master LB (Admin Console)
az network lb rule create \
    --resource-group ${OPENSHIFT_RG} \
    --lb-name okd-${CLUSTER_NAME}-master-lb \
    --name AdminConsoleHTTPS \
    --protocol tcp \
    --frontend-port 443 \
    --backend-port 443 \
    --frontend-ip-name master-lb-frontend-pool \
    --backend-pool-name master-lb-backend-pool \
    --probe-name master-lb-https-probe

# ------------------------------------------------------------------------------

# Router LB (to Infrastructure nodes)
az network lb create \
	--name okd-${CLUSTER_NAME}-router-lb \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION} \
	--sku Basic \
	--public-ip-address-allocation static \
	--public-ip-address okd-${CLUSTER_NAME}-router-lb-ip \
	--vnet-name ${VNET_NAME} \
	--frontend-ip-name router-lb-frontend-pool \
	--backend-pool-name router-lb-backend-pool

# Health Probe for HTTP Traffic to the Router LB
az network lb probe create \
	--resource-group  ${OPENSHIFT_RG} \
	--lb-name okd-${CLUSTER_NAME}-router-lb \
	--name router-lb-http-probe \
	--protocol tcp \
	--port 80

# LB Rule for HTTP Traffic to the Router LB
az network lb rule create \
    --resource-group ${OPENSHIFT_RG} \
    --lb-name okd-${CLUSTER_NAME}-router-lb \
    --name RouterHTTP \
    --protocol tcp \
    --frontend-port 80 \
    --backend-port 80 \
    --frontend-ip-name router-lb-frontend-pool \
    --backend-pool-name router-lb-backend-pool \
    --probe-name router-lb-http-probe

# Health Probe for HTTPS Traffic to the Router LB
az network lb probe create \
	--resource-group  ${OPENSHIFT_RG} \
	--lb-name okd-${CLUSTER_NAME}-router-lb \
	--name router-lb-https-probe \
	--protocol tcp \
	--port 443

# LB Rule for HTTPS Traffic to the Router LB
az network lb rule create \
    --resource-group ${OPENSHIFT_RG} \
    --lb-name okd-${CLUSTER_NAME}-router-lb \
    --name RouterHTTPS \
    --protocol tcp \
    --frontend-port 443 \
    --backend-port 443 \
    --frontend-ip-name router-lb-frontend-pool \
    --backend-pool-name router-lb-backend-pool \
    --probe-name router-lb-https-probe
