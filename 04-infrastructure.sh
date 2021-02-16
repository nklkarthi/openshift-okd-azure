#!/bin/bash
source 00-configuration.sh

# ------------------------------------------------------------------------------
# Public Key
SSH_PUBLIC_KEY=$(cat ~/.ssh/okd_rsa.pub)

# ----------------------------------------------------------
# Virtual Machines
# 
# ----------------------------------------------------------
# Bastion Host
az network public-ip create \
	--name okd-bastion-nic-public-ip \
	--resource-group ${OPENSHIFT_RG} \
	--version IPv4 \
	--sku Basic \
	--allocation-method Static

az network nic create \
	--name okd-bastion-nic \
	--resource-group ${OPENSHIFT_RG} \
	--vnet-name ${VNET_NAME} \
	--subnet ${DMZ_SUBNET_NAME} \
	--public-ip-address okd-bastion-nic-public-ip \
	--network-security-group ""

az vm create \
	--name okd-bastion \
	--resource-group ${OPENSHIFT_RG} \
	--size ${MASTER_INSTANCE_SIZE} \
	--image ${MASTER_INSTANCE_IMAGE} \
	--tags "openshift, bastion" \
	--authentication-type "ssh" \
	--admin-username ${USERNAME} \
	--ssh-key-value "${SSH_PUBLIC_KEY}" \
	--nics okd-bastion-nic \
	--availability-set ${MASTER_AVAILABILITY_SET_NAME}

# ----------------------------------------------------------
# Three Master Instances in a Master Availability Set
for i in `seq ${MASTER_INSTANCE_COUNT}`; do
	az network nic create \
	    --name okd-master-${i}-nic \
	    --resource-group ${OPENSHIFT_RG} \
	    --vnet-name ${VNET_NAME} \
	    --subnet ${PRIVATE_SUBNET_NAME} \
	    --network-security-group "" \
	    --public-ip-address "" \
	    --lb-name okd-${CLUSTER_NAME}-master-lb \
	    --lb-address-pools master-lb-backend-pool;

	az vm create \
		--name okd-master-${i} \
		--resource-group ${OPENSHIFT_RG} \
		--size ${MASTER_INSTANCE_SIZE} \
		--image ${MASTER_INSTANCE_IMAGE} \
		--tags "openshift, master" \
		--authentication-type "ssh" \
		--admin-username ${USERNAME} \
		--ssh-key-value "${SSH_PUBLIC_KEY}" \
		--nics okd-master-${i}-nic \
		--availability-set ${MASTER_AVAILABILITY_SET_NAME};
done

# ----------------------------------------------------------
# Three Infrastructure Instances in an Infrastructure Availability Set
for i in `seq ${INFRASTRUCTURE_INSTANCE_COUNT}`; do
	az network nic create \
		--name okd-infastructure-${i}-nic \
	    --resource-group ${OPENSHIFT_RG} \
	    --vnet-name ${VNET_NAME} \
	    --subnet ${PRIVATE_SUBNET_NAME} \
	    --network-security-group "" \
	    --public-ip-address "" \
	    --lb-name okd-${CLUSTER_NAME}-router-lb \
	    --lb-address-pools router-lb-backend-pool;

	az vm create \
		--name okd-infrastructure-${i} \
		--resource-group ${OPENSHIFT_RG} \
		--size ${INFRASTRUCTURE_INSTANCE_SIZE} \
		--image ${INFRASTRUCTURE_INSTANCE_IMAGE} \
		--tags "openshift, infrastructure" \
		--authentication-type "ssh" \
		--admin-username ${USERNAME} \
		--ssh-key-value "${SSH_PUBLIC_KEY}" \
		--nics okd-infastructure-${i}-nic \
		--availability-set ${INFRASTRUCTURE_AVAILABILITY_SET_NAME};
done

# ----------------------------------------------------------
# Three Application Instances in an Application Availability Set
for i in `seq ${APPLICATION_INSTANCE_COUNT}`; do
	az network nic create \
	    --name okd-application-${i}-nic \
	    --resource-group ${OPENSHIFT_RG} \
	    --vnet-name ${VNET_NAME} \
	    --subnet ${PRIVATE_SUBNET_NAME} \
	    --network-security-group "" \
	    --public-ip-address ""; 

	az vm create \
		--name okd-application-${i} \
		--resource-group ${OPENSHIFT_RG} \
		--size ${APPLICATION_INSTANCE_SIZE} \
		--image ${APPLICATION_INSTANCE_IMAGE} \
		--tags "openshift, application" \
		--authentication-type "ssh" \
		--admin-username ${USERNAME} \
		--ssh-key-value "${SSH_PUBLIC_KEY}" \
		--nics okd-application-${i}-nic \
		--availability-set ${APPLICATION_AVAILABILITY_SET_NAME};
done