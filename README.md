# BankDemoK8S
Configuration files required for the BankDemoK8s Guide

## Automatic installation

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MicroPJ/BankDemoK8S/main/install.sh)"

## `.env` File Configuration

The `.env` file allows the script to run without user interaction by predefining certain variables. Below is a template for the `.env` file:

```env
VERBOSE=y
DOCKER_USERNAME=your_docker_username
DOCKER_PASSWORD=your_docker_password
UPGRADE_OS=n
SERVER_IP=192.168.1.100
RECREATE_CLUSTER=y
BANKDEMO_IMAGE=docker.io/yourusername/customimage:tag
