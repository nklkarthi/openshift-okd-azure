#!/bin/bash

# Load config
source 00-configuration.sh

# Login to Azure Sign in to your Azure subscription with the az login command
# and follow the on-screen directions, or click Try it to use Cloud Shell.
# az login

# Create a resource group Create a resource group with the az group create
# command. An Azure resource group is a logical container into which Azure
# resources are deployed and managed. It is recommended to use a dedicated
# resource group to host the key vault. This group is separate from the
# resource group into which the OpenShift cluster resources deploy.
az group create \
	--name ${OPENSHIFT_RG} \
	--location ${LOCATION}

# Create a key vault to store the SSH keys for the cluster with the az
# keyvault create command. The key vault name must be globally unique.
az keyvault create \
	--name ${KEYVAULT_NAME} \
	--resource-group ${OPENSHIFT_RG} \
	--enabled-for-template-deployment true \
	--location ${LOCATION}

# Create a dedicated SSH Key for the cluster
ssh-keygen -f ./ssh/okd_rsa -t rsa -N ''

# Store the SSH private key in Azure Key Vault
# The OpenShift deployment uses the SSH key you created to secure access to
# the OpenShift master. To enable the deployment to securely retrieve the SSH
# key, store the key in Key Vault by using the following command:
az keyvault secret set \
	--vault-name ${KEYVAULT_NAME} \
	--name keysecret \
	--file ./ssh/okd_rsa