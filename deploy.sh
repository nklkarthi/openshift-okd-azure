#!/bin/bash

# Before running this script ensure you are logged in to the correct subscription
# az login

# You can customize the cluster by editing 00-configuration.sh

# Prepare Security Infrastructure
./01-prepare-keyvault.sh

# Prepare Service Principal and render configuration files
./02-az-resources.sh

# Create the network layer
./03-network.sh

# Create the infrastructure layer
./04-infrastructure.sh

# Provision OKD 3.11
./05-provision-nodes.sh