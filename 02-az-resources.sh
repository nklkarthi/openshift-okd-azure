#!/bin/bash
source 00-configuration.sh

# ------------------------------------------------------------------------------
# Service Principal
# ------------------------------------------------------------------------------
# Create a service principal OpenShift communicates with Azure by using a
# username and password or a service principal. An Azure service principal is
# a security identity that you can use with apps, services, and automation
# tools like OpenShift. You control and define the permissions as to which
# operations the service principal can perform in Azure. It is best to scope
# the permissions of the service principal to specific resource groups rather
# than the entire subscription.

# Need to remove quotation marks
# https://ecwpz91.github.io/2018/07/09/Deploying-OpenShift-on-Azure.html
SP_SCOPE=`az group show \
	--name ${OPENSHIFT_RG} \
	--query id | sed -e 's/\"\(.*\)\"/\1/'`

SP_JSON=`az ad sp create-for-rbac \
	--name ${OPENSHIFT_SP} \
	--role Contributor \
	--scopes ${SP_SCOPE}`

# ------------------------------------------------------------------------------
# Storage Account
# ------------------------------------------------------------------------------
# A Storage Account allow for resources, such as virtual machines, to access
# the different type of storage components offered by Microsoft Azure. During
# installation, the storage account defines the location of the object-based
# blob storage used for the OpenShift Container Platform registry.
az storage account create \
	--name ${STORAGE_ACCOUNT_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--kind ${STORAGE_KIND} \
	--location ${LOCATION} \
	--sku ${STORAGE_SKU}

# ------------------------------------------------------------------------------
# Availability Sets
# ------------------------------------------------------------------------------
# Availability sets ensure that the deployed VMs are distributed across multiple
# isolated hardware nodes in a cluster. The distribution helps to ensure that
# when maintenance on the cloud provider hardware occurs, instances will not
# all run on one specific node. You should segment instances to different
# availability sets based on their role. For example, one availability set
# containing three master hosts, one availability set containing
# infrastructure hosts, and one availability set containing application hosts.
# This allows for segmentation and the ability to use external load balancers
# within OpenShift Container Platform.

az vm availability-set create \
	--name ${MASTER_AVAILABILITY_SET_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION}

az vm availability-set create \
	--name ${INFRASTRUCTURE_AVAILABILITY_SET_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION}

az vm availability-set create \
	--name ${APPLICATION_AVAILABILITY_SET_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--location ${LOCATION}

# Create ourput dir if not exists
mkdir -p out

# ------------------------------------------------------------------------------
# Gather required information
# ------------------------------------------------------------------------------
SP_ID=$(echo ${SP_JSON} | python3 -c "import sys, json; print(json.load(sys.stdin)['appId'])")
SP_PASSWORD=$(echo ${SP_JSON} | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")
SP_TENANT_ID=$(echo ${SP_JSON} | python3 -c "import sys, json; print(json.load(sys.stdin)['tenant'])")

ACCOUNT_JSON=$(az account show)
SUBSCRIPTION_ID=$(echo ${ACCOUNT_JSON} | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
SUBSCRIPTION_TENANT_ID=$(echo ${ACCOUNT_JSON} | python3 -c "import sys, json; print(json.load(sys.stdin)['tenantId'])")
SUBSCRIPTION_CLOUD=$(echo ${ACCOUNT_JSON} | python3 -c "import sys, json; print(json.load(sys.stdin)['environmentName'])")

STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name ${STORAGE_ACCOUNT_NAME} | python3 -c "import sys, json; print(json.load(sys.stdin)[0]['value'])")

# ------------------------------------------------------------------------------
# Render Configuration files for master, infrastructure and application nodes,
# these files are required later on during the Ansible install step.
# https://docs.okd.io/3.11/install_config/configuring_azure.html#azure-configuration-file
# ------------------------------------------------------------------------------

for i in master infrastructure application; do
	echo "tenantId: ${SUBSCRIPTION_TENANT_ID}" > ./out/azure.${i}.conf;
	echo "subscriptionId: ${SUBSCRIPTION_ID}" >> ./out/azure.${i}.conf;
	echo "aadClientId: ${SP_ID}" >> ./out/azure.${i}.conf;
	echo "aadClientSecret: ${SP_PASSWORD}" >> ./out/azure.${i}.conf;
	echo "aadTenantId: ${SP_TENANT_ID}" >> ./out/azure.${i}.conf;
	echo "resourceGroup: ${OPENSHIFT_RG}" >> ./out/azure.${i}.conf;
	echo "cloud: ${SUBSCRIPTION_CLOUD}" >> ./out/azure.${i}.conf;
	echo "location: ${LOCATION}" >> ./out/azure.${i}.conf;
	echo "vnetName: ${VNET_NAME}" >> ./out/azure.${i}.conf;
done

echo "primaryAvailabilitySetName: ${MASTER_AVAILABILITY_SET_NAME}" >> ./out/azure.master.conf
echo "primaryAvailabilitySetName: ${INFRASTRUCTURE_AVAILABILITY_SET_NAME}" >> ./out/azure.infrastructure.conf
echo "primaryAvailabilitySetName: ${APPLICATION_AVAILABILITY_SET_NAME}" >> ./out/azure.application.conf

# ------------------------------------------------------------------------------
# Render Ansible Inventory File for This Cluster from Template
# https://docs.okd.io/3.11/install_config/configuring_azure.html#example-inventory-file-azure_configuring-for-azure
# ------------------------------------------------------------------------------
cp ./lib/ansible-inventory.template ./out/inventory.ini
sed -i "" -e "s/AZURE_SP_APP_ID/${SP_ID}/g" ./out/inventory.ini
sed -i "" -e "s/AZURE_SP_APP_PASSWORD/${SP_PASSWORD}/g" ./out/inventory.ini
sed -i "" -e "s/AZURE_SP_TENANT_ID/${SP_TENANT_ID}/g" ./out/inventory.ini

sed -i "" -e "s/AZURE_SUBSCRIPTION_ID/${SUBSCRIPTION_ID}/g" ./out/inventory.ini
sed -i "" -e "s/AZURE_RESOURCE_GROUP/${OPENSHIFT_RG}/g" ./out/inventory.ini
sed -i "" -e "s/AZURE_LOCATION/${LOCATION}/g" ./out/inventory.ini

sed -i "" -e "s/OKD_USERNAME/${USERNAME}/g" ./out/inventory.ini
sed -i "" -e "s/OKD_HASHED_PASSWORD/${PASSWORD}/g" ./out/inventory.ini

sed -i "" -e "s/NUM_ROUTER_REPLICAS/${MASTER_INSTANCE_COUNT}/g" ./out/inventory.ini
sed -i "" -e "s/AZURE_STORAGE_ACCOUNT_TYPE/${STORAGE_SKU}/g" ./out/inventory.ini

sed -i "" -e "s/REDHAT_REGISTRY_USERNAME/${REDHAT_REGISTRY_USERNAME}/g" ./out/inventory.ini
sed -i "" -e "s/REDHAT_REGISTRY_PASSWORD/${REDHAT_REGISTRY_PASSWORD}/g" ./out/inventory.ini

sed -i "" -e "s/MASTER_PRIVATE_HOSTNAME/${DNS_MASTER_NAME}/g" ./out/inventory.ini
sed -i "" -e "s/MASTER_PUBLIC_HOSTNAME/${DNS_MASTER_NAME}/g" ./out/inventory.ini
sed -i "" -e "s/MASTER_DEFAULT_SUBDOMAIN/${DNS_ROUTER_NAME}/g" ./out/inventory.ini

sed -i "" -e "s/AZURE_STORAGE_ACCOUNT_NAME/${STORAGE_ACCOUNT_NAME}/g" ./out/inventory.ini
sed -i "" -e "s/AZURE_STORAGE_ACCOUNT_KEY/${STORAGE_ACCOUNT_KEY}/g" ./out/inventory.ini

echo "[masters]" >> ./out/inventory.ini
for i in `seq ${MASTER_INSTANCE_COUNT}`; do
	echo "okd-master-${i}" >> ./out/inventory.ini
done
echo "\n" >> ./out/inventory.ini

echo "[etcd]" >> ./out/inventory.ini
for i in `seq ${MASTER_INSTANCE_COUNT}`; do
	echo "okd-master-${i}" >> ./out/inventory.ini
done
echo "\n" >> ./out/inventory.ini

echo "[nodes]" >> ./out/inventory.ini
for i in `seq ${MASTER_INSTANCE_COUNT}`; do
	echo "okd-master-${i} openshift_node_group_name=\"node-config-master\"" >> ./out/inventory.ini
done
for i in `seq ${INFRASTRUCTURE_INSTANCE_COUNT}`; do
	echo "okd-infrastructure-${i} openshift_node_group_name=\"node-config-infra\"" >> ./out/inventory.ini
done
for i in `seq ${APPLICATION_INSTANCE_COUNT}`; do
	echo "okd-application-${i} openshift_node_group_name=\"node-config-compute\"" >> ./out/inventory.ini
done