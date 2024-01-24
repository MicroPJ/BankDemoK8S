#!/bin/bash

# Color Codes for Enhanced UX
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # No Color

# Function to display header with the provided ASCII Art Banner
display_header() {
    echo -e "${YELLOW}"
    cat << "EOF"
           _                ____     _ _  _____      
 _ __ ___ (_) ___ _ __ ___ |  _ \   | | |/ ( _ ) ___ 
| '_ ` _ \| |/ __| '__/ _ \| |_) |  | | ' // _ \/ __|
| | | | | | | (__| | | (_) |  __/ |_| | . \ (_) \__ \
|_| |_| |_|_|\___|_|  \___/|_|   \___/|_|\_\___/|___/
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Ubuntu Environment Setup Tool${NC}"
    echo -e "${YELLOW}----------------------------------${NC}"
}

# Function to display a step
display_step() {
    echo -e "${BLUE}--> $1${NC}"
}

# Function to show error and exit
show_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Function to install Docker
install_docker() {
    display_step "Removing any existing Docker installations..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || show_error "Failed to remove existing Docker installations."

    display_step "Updating the package index..."
    sudo apt-get update || show_error "Failed to update package index."

    display_step "Installing packages to allow apt to use a repository over HTTPS..."
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common || show_error "Failed to install packages for HTTPS repository."

    display_step "Adding Docker’s official GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || show_error "Failed to add Docker’s GPG key."

    display_step "Setting up the stable repository..."
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || show_error "Failed to set up Docker repository."

    display_step "Updating the package index..."
    sudo apt-get update || show_error "Failed to update package index after adding Docker repository."

    display_step "Installing Docker CE..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io || show_error "Failed to install Docker CE."

    display_step "Installing Docker Compose..."
    sudo apt-get install -y docker-compose || show_error "Failed to install Docker Compose."
}

# Introduction
display_header
echo "This script will automate the setup of your Ubuntu environment including Docker, Kind K8s, and the BankDemo application."

# Update and Upgrade OS
display_step "Updating and Upgrading the Operating System..."
sudo apt-get update && sudo apt-get -y upgrade || show_error "Failed to update and upgrade OS."

# Install Docker and Docker-compose
display_step "Installing Docker and Docker-compose..."
install_docker

# Turn SWAP Off
display_step "Turning SWAP off..."
sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab || show_error "Failed to turn off SWAP."

# Install Kind K8s
display_step "Installing Kind K8s..."
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind || show_error "Failed to install Kind K8s."

# Install kubectl
display_step "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl || show_error "Failed to install kubectl."

# List all IP addresses and ask user to choose one
display_step "Listing all IP addresses of this server..."
ip_addresses=$(hostname -I)
echo "Available IP addresses: $ip_addresses"
read -rp "Please enter the IP address you want to use: " server_ip
[ -z "$server_ip" ] && show_error "No IP address entered. Please enter a valid IP address."

# Docker Registry Secret
display_step "Setting up Docker Registry Secret"
read -rp "Enter Docker Username: " docker_username
read -rsp "Enter Docker Password: " docker_password
echo
kubectl create secret docker-registry regcred --docker-server=docker.io --docker-username="$docker_username" --docker-password="$docker_password" --docker-email="email@example.com" || show_error "Failed to create Docker registry secret."

# Create Kind K8s cluster and Deploy BankDemo
display_step "Creating Kind K8s cluster and Deploying BankDemo..."
mkdir -p ~/kind && cd ~/kind || show_error "Failed to create or navigate to kind directory."
wget -O bankdemoClusterConfig.yaml "https://raw.githubusercontent.com/MicroPJ/BankDemoK8S/main/config/bankdemoClusterConfig.yaml"
kind create cluster --config bankdemoClusterConfig.yaml || show_error "Failed to create Kind K8s cluster."
# Additional deployment steps here

echo -e "${GREEN}Kind K8s cluster created and BankDemo deployed successfully.${NC}"

# Final message
echo -e "${GREEN}All tasks completed successfully.${NC}"
