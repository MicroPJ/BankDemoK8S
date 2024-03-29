#!/bin/bash

# Color Codes for Enhanced UX
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # No Color

# Global verbose flag
VERBOSE=false

# Function to execute a command with or without verbose output and continue on error
execute_command() {
    local command=$1
    if [ "$VERBOSE" = true ]; then
        eval "$command" || echo -e "${RED}Warning: Command failed but continuing: $command${NC}"
    else
        eval "$command" > /dev/null 2>&1 || echo -e "${RED}Warning: Command failed but continuing: $command${NC}"
    fi
}

# Function to display header with the provided ASCII Art Banner
display_header() {
    clear
    echo -e "${YELLOW}"
    cat << "EOF"
 ___      ___  ___  __   __   __     __   ___     __   __   __  
|__  |\ |  |  |__  |__) |__) |__) | /__` |__     /  ` /__` |__) 
|___ | \|  |  |___ |  \ |    |  \ | .__/ |___    \__, .__/ |    
                                                                
EOF
    echo -e "${NC}"
    echo -e "${GREEN}Ubuntu BankDemo K8s Environment Setup Tool${NC}"
    echo -e "${YELLOW}------------------------------------------${NC}"
}

# Function to display a step
display_step() {
    echo -e "${YELLOW}--> $1${NC}"
}

# Function to show error and exit
show_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Function to update the OS
update_os() {
    display_step "Updating the Operating System..."
    execute_command "sudo apt-get update"
}

# Function to upgrade the OS
upgrade_os() {
    display_step "Upgrading the Operating System..."
    execute_command "sudo apt-get -y upgrade"
}

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
    execute_command "sudo add-apt-repository -y \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\""

    display_step "Updating the package index..."
    execute_command "sudo apt-get update"

    display_step "Installing Docker CE..."
    execute_command "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"

    display_step "Installing Docker Compose..."
    execute_command "sudo apt-get install -y docker-compose"
}

# Function to create Docker Registry Secret
create_docker_registry_secret() {
    get_or_prompt DOCKER_USERNAME "Enter Docker Username: " ""
    get_or_prompt DOCKER_PASSWORD "Enter Docker Password: " "" -s
    echo
    execute_command "kubectl create secret docker-registry regcred --docker-server=docker.io --docker-username=\"$DOCKER_USERNAME\" --docker-password=\"$DOCKER_PASSWORD\" --docker-email=\"email@example.com\""
}

# Function to handle Docker Registry Secret
handle_docker_registry_secret() {
    display_step "Configuring Docker Registry Secret"

    # Checking if the secret already exists
    if kubectl get secret regcred > /dev/null 2>&1; then
        echo "Docker registry secret 'regcred' already exists."
        get_or_prompt RECREATE_SECRET "Do you want to delete and recreate it? (y/n): " "n"
        if [[ $RECREATE_SECRET == "y" ]]; then
            execute_command "kubectl delete secret regcred"
            create_docker_registry_secret
        else
            echo "Skipping Docker registry secret creation."
        fi
    else
        create_docker_registry_secret
    fi
}

# Function to get and select IP address
select_ip_address() {
    # Use SERVER_IP from .env file if available
    if [ ! -z "$SERVER_IP" ]; then
        server_ip="$SERVER_IP"
        echo "Using server IP from .env file: $server_ip"
        return
    fi

    echo "Detecting available IP addresses..."
    local ips=($(hostname -I))

    # Optionally add public IP from an external service
    local public_ip=$(curl -s https://api.ipify.org)
    if [ ! -z "$public_ip" ]; then
        ips+=("$public_ip")
    fi

    echo "Available IP addresses:"
    for i in "${!ips[@]}"; do
        echo "[$((i+1))] ${ips[$i]}"
    done

    local ip_choice
    read -rp "Please select the IP address by number (e.g., 1): " ip_choice

    # Validate selection
    if [[ -z ${ips[$((ip_choice-1))]} ]]; then
        show_error "Invalid selection. Please run the script again and select a valid number."
    fi

    server_ip=${ips[$((ip_choice-1))]}
    echo "You have selected: $server_ip"
}

# Function to handle Kind K8s cluster creation
handle_kind_cluster_creation() {
    display_step "Setting up Kind K8s cluster"

    # Checking if the cluster already exists
    if kind get clusters | grep -q "bankdemo-kind"; then
        echo "A Kind K8s cluster named 'bankdemo-kind' already exists."

        # Use RECREATE_CLUSTER from .env file if available
        if [ ! -z "$RECREATE_CLUSTER" ]; then
            recreate_cluster_choice="$RECREATE_CLUSTER"
            echo "Using RECREATE_CLUSTER from .env file: $recreate_cluster_choice"
        else
            read -rp "Do you want to delete and recreate it? (y/n): " recreate_cluster_choice
        fi

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
    # Call the function to check if the Kubernetes cluster is ready
    check_cluster_ready
}

# Function to check if the Kubernetes cluster is ready
check_cluster_ready() {
    local max_attempts=3
    local attempt=1
    local cluster_ready=false

    echo "Checking if the Kubernetes cluster is ready..."

    while [ $attempt -le $max_attempts ]; do
        if kubectl cluster-info &> /dev/null; then
            echo "Kubernetes cluster is ready."
            cluster_ready=true
            break
        else
            echo "Waiting for Kubernetes cluster to become ready (Attempt $attempt of $max_attempts)..."
            sleep 10
        fi
        ((attempt++))
    done

    if [ "$cluster_ready" = false ]; then
        show_error "Kubernetes cluster is not ready after $max_attempts attempts. Please check the Kind cluster status."
    fi
}

# Function to update Docker image in bankdemoDeployment.yaml
update_bankdemo_deployment_image() {
    local default_image="docker.io/micropj/microfocus:bankdemo"
    local new_image="$BANKDEMO_IMAGE" # This can be set in the .env file

    echo "The current Docker image is set to: $default_image"

    # Check if a new Docker image was provided in the .env file
    if [ -z "$new_image" ]; then
        read -rp "Do you wish to change the default Docker image? (y/n): " change_image
        if [[ $change_image == "y" ]]; then
            read -rp "Enter the new Docker image: " new_image
        fi
    fi

    # Update the Docker image if it's different from the default
    if [ ! -z "$new_image" ] && [ "$new_image" != "$default_image" ]; then
        execute_command "sed -i 's|$default_image|$new_image|g' bankdemoDeployment.yaml"
        echo "Docker image updated to: $new_image"
    else
        echo "Keeping the default Docker image."
    fi
}


# Function to set up Kubernetes cluster components
setup_kubernetes_components() {
    display_step "Applying Ingress for Kind K8s cluster"
    execute_command "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"

    display_step "Deleting ValidatingWebhookConfiguration for ingress-nginx"
    execute_command "kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission"

    display_step "Fetching cluster information"
    execute_command "kubectl cluster-info"

    # Deploy K8s Dashboard
    display_step "Deploying Kubernetes Dashboard"
    execute_command "kubectl apply -f https://raw.githubusercontent.com/MicroPJ/BankDemoK8S/main/config/dashboardRecommended.yaml"
    execute_command "kubectl apply -f https://raw.githubusercontent.com/MicroPJ/BankDemoK8S/main/config/clusterRole.yaml"

    display_step "Downloading and applying dashboard deployment configuration"
    execute_command "wget -O dashboardDeployment.yaml https://raw.githubusercontent.com/MicroPJ/BankDemoK8S/main/config/dashboardDeployment.yaml"
    execute_command "sed -i 's/10.27.27.63/${server_ip}/g' dashboardDeployment.yaml"
    execute_command "kubectl apply -f dashboardDeployment.yaml"

    # Deploy BankDemo
    display_step "Deploying BankDemo"
    execute_command "wget -O bankdemoDeployment.yaml https://raw.githubusercontent.com/MicroPJ/BankDemoK8S/main/config/bankdemoDeployment.yaml"
    update_bankdemo_deployment_image
    execute_command "sed -i 's/10.27.27.63/${server_ip}/g' bankdemoDeployment.yaml"
    # If needed, add logic here to replace the Docker image line with your own Docker Hub image
    execute_command "kubectl apply -f bankdemoDeployment.yaml"
}

# Function to display information in a user-friendly ASCII box
display_end_info() {
    local ip=$1

    echo -e "${YELLOW}---------------------------------------------------${NC}"
    echo -e "${GREEN} Setup Completed Successfully! ${NC}"
    echo -e "${YELLOW}---------------------------------------------------${NC}"
    echo -e "${YELLOW}Access the following URLs with your selected IP: ${ip}${NC}"
    echo "  Go to http://escwa.${ip}.nip.io"
    echo "  Go to http://hacloud.${ip}.nip.io"
    echo "  Go to http://dashboard.${ip}.nip.io"
    echo "  Go to http://dashboard.${ip}.nip.io/#/workloads?namespace=default"
    echo
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  kubectl scale --replicas=4 deployment bankdemo-deployment"
    echo "  kubectl get node -owide"
    echo "  kubectl get pod -owide"
    echo "  kubectl describe pod bankdemo-deployment-XXXXX-YYYYY"
    echo "  kubectl delete -f bankdemoDeployment.yaml"
    echo "  kubectl delete daemonsets, replicasets, services, deployments, pods, rc, ingress --all --all-namespaces"
    echo "  kind delete cluster --name bankdemo-kind"
    echo -e "${YELLOW}---------------------------------------------------${NC}"
}

# Function to get or prompt for a value
get_or_prompt() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3

    if [ -z "${!var_name}" ]; then
        read -rp "$prompt_message" $var_name
        export $var_name=${!var_name:-$default_value}
    fi
}

# Introduction
display_header
echo "This script will automate the setup of your Ubuntu environment including Docker, Kind K8s, and the BankDemo application."

# Load .env file if it exists
if [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | xargs)
fi

# Ask user if they want verbose output or use value from .env file
get_or_prompt VERBOSE "Do you want to enable verbose output? (y/n): " "n"

# Update OS
update_os

# Ask user if they want to upgrade the OS or use value from .env file
get_or_prompt UPGRADE_OS "Do you want to upgrade the operating system? (y/n): " "n"
if [[ $UPGRADE_OS == "y" ]]; then
    upgrade_os
fi

# Install Docker and Docker-compose
install_docker

# Turn SWAP Off
display_step "Turning SWAP off..."
execute_command "sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab"

# Install Kind K8s
display_step "Installing Kind K8s..."
execute_command "curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"

# Install kubectl
display_step "Installing kubectl..."
execute_command "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"

# Call the function to select IP address
display_step "Select IP Address to use..."
select_ip_address 

# Create Kind K8s cluster and Deploy BankDemo
display_step "Create K8s Cluster..."
handle_kind_cluster_creation

# Handle Docker Registry Secret
display_step "Create Docker Hub login secret..."
handle_docker_registry_secret

# Call the function to setup Kubernetes components after cluster creation
display_step "Create and deploy K8s Dashboard and BankDemo..."
setup_kubernetes_components

# Final message
display_end_info "$server_ip"
