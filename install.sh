#!/bin/bash

# Color Codes for Enhanced UX
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # No Color

# Global verbose flag
VERBOSE=false

# Function to execute a command with or without verbose output
execute_command() {
    local command=$1
    if [ "$VERBOSE" = true ]; then
        eval $command || show_error "Command failed: $command"
    else
        eval $command > /dev/null 2>&1 || show_error "Command failed: $command"
    fi
}

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

# Ask user if they want verbose output
echo -e "${BLUE}Do you want to enable verbose output? (y/n)${NC}"
read -rp "Choice: " choice
if [[ $choice == "y" ]]; then
    VERBOSE=true
fi

# Function to install Docker
install_docker() {
    display_step "Removing any existing Docker installations..."
    execute_command "sudo apt-get remove -y docker docker-engine docker.io containerd runc"

    display_step "Updating the package index..."
    execute_command "sudo apt-get update"

    display_step "Installing packages to allow apt to use a repository over HTTPS..."
    execute_command "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common"

    display_step "Adding Docker’s official GPG key..."
    execute_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"

    display_step "Setting up the stable repository..."
    execute_command "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\""

    display_step "Updating the package index..."
    execute_command "sudo apt-get update"

    display_step "Installing Docker CE..."
    execute_command "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"

    display_step "Installing Docker Compose..."
    execute_command "sudo apt-get install -y docker-compose"
}

# Function to handle Docker Registry Secret
handle_docker_registry_secret() {
    display_step "Configuring Docker Registry Secret"

    # Checking if the secret already exists
    if kubectl get secret regcred > /dev/null 2>&1; then
        echo "Docker registry secret 'regcred' already exists."
        read -rp "Do you want to delete and recreate it? (y/n): " recreate_choice
        if [[ $recreate_choice == "y" ]]; then
            execute_command "kubectl delete secret regcred"
            create_docker_registry_secret
        else
            echo "Skipping Docker registry secret creation."
        fi
    else
        create_docker_registry_secret
    fi
}

# Function to create Docker Registry Secret
create_docker_registry_secret() {
    read -rp "Enter Docker Username: " docker_username
    read -rsp "Enter Docker Password: " docker_password
    echo
    execute_command "kubectl create secret docker-registry regcred --docker-server=docker.io --docker-username=\"$docker_username\" --docker-password=\"$docker_password\" --docker-email=\"email@example.com\""
}

# Function to handle Kind K8s cluster creation
handle_kind_cluster_creation() {
    display_step "Setting up Kind K8s cluster"

    # Checking if the cluster already exists
    if kind get clusters | grep -q "bankdemo-kind"; then
        echo "A Kind K8s cluster named 'bankdemo-kind' already exists."
        read -rp "Do you want to delete and recreate it? (y/n): " recreate_cluster_choice
        if [[ $recreate_cluster_choice == "y" ]]; then
            execute_command "kind delete cluster --name bankdemo-kind"
            create_kind_cluster
        else
            echo "Skipping Kind K8s cluster creation."
        fi
    else
        create_kind_cluster
    fi
}

# Function to create Kind K8s cluster
create_kind_cluster() {
    execute_command "wget -O bankdemoClusterConfig.yaml \"https://raw.githubusercontent.com/MicroPJ/BankDemoK8S/main/config/bankdemoClusterConfig.yaml\""
    execute_command "kind create cluster --config bankdemoClusterConfig.yaml --name bankdemo-kind"
}

# Function to display information in a user-friendly ASCII box
display_end_info() {
    local ip=$1

    echo -e "${YELLOW}---------------------------------------------------${NC}"
    echo -e "${GREEN} Setup Completed Successfully! ${NC}"
    echo -e "${YELLOW}---------------------------------------------------${NC}"
    echo -e "${BLUE}Access the following URLs with your selected IP: ${ip}${NC}"
    echo "  Go to http://escwa.${ip}.nip.io"
    echo "  Go to http://hacloud.${ip}.nip.io"
    echo "  Go to http://dashboard.${ip}.nip.io"
    echo "  Go to http://dashboard.${ip}.nip.io/#/workloads?namespace=default"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  kubectl scale --replicas=4 deployment bankdemo-deployment"
    echo "  kubectl get node -owide"
    echo "  kubectl get pod -owide"
    echo "  kubectl describe pod bankdemo-deployment-XXXXX-YYYYY"
    echo "  kubectl delete -f bankdemoDeployment.yaml"
    echo "  kubectl delete daemonsets, replicasets, services, deployments, pods, rc, ingress --all --all-namespaces"
    echo "  kind delete cluster --name bankdemo-kind"
    echo -e "${YELLOW}---------------------------------------------------${NC}"
}

# Introduction
display_header
echo "This script will automate the setup of your Ubuntu environment including Docker, Kind K8s, and the BankDemo application."

# Update and Upgrade OS
display_step "Updating and Upgrading the Operating System..."
execute_command "sudo apt-get update && sudo apt-get -y upgrade
