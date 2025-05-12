# LXD NGINX-Proxy for Kubernetes

This project provides an Ansible playbook to automate the deployment of an LXD container running NGINX-proxy. The primary purpose of this proxy is to act as the Kubernetes API aggregation layer, with a secondary goal of providing a consistent ingress point for services exposed by the Kubernetes environment.

## Overview

The NGINX-proxy container serves two main functions:

1. **Kubernetes API Aggregation Layer**: Acts as a proxy for the Kubernetes API server, allowing for a consistent endpoint regardless of the underlying infrastructure.
2. **Ingress Controller**: Provides a consistent entry point for accessing services exposed by the Kubernetes cluster.

## Logical Diagrams to explain the goal

### Traffic Flow

This diagram tries to explain how the IP traffic will flow within the local system.

![Traffic Flow](./diagrams/local-ai-traffic-Traffic.drawio.svg)

### DNS Resolution based on topology scenario

This diagram tries to explain when/why you need to manipulate the local DNS resolution mechanics within the local system to always be able to reach endpoints via FQDN.

![DNS Resolution](./diagrams/local-ai-traffic-DNS.drawio.svg)

## Requirements

- Ubuntu 24.04 server with X11
- LXD already installed and configured
- Ansible installed in a Python virtual environment

## Project Structure

```
.
├── ansible.cfg                  # Ansible configuration
├── inventory/                   # Inventory files
│   └── hosts.yaml               # Host inventory
├── lxd_nginx_proxy.yaml         # Main playbook for deployment
├── lxd_nginx_proxy_remove.yaml  # Playbook for removal
├── roles/                       # Ansible roles
│   └── lxd_nginx_proxy/         # LXD NGINX-proxy role
│       ├── defaults/            # Default variables
│       ├── files/               # Static files
│       ├── handlers/            # Handlers
│       ├── meta/                # Role metadata
│       ├── tasks/               # Tasks
│       ├── templates/           # Jinja2 templates
│       └── vars/                # Role variables
├── global/                      # Global configuration files
├── online/                      # Online configuration files
├── ssl/                         # SSL certificates
├── NOTES.md                     # Manual installation instructions
└── README.md                    # This file
```

## Features

- **Idempotent Deployment**: All tasks are designed to be idempotent, ensuring consistent results regardless of how many times they are run.
- **Dummy Interface**: Creates a virtual interface with a static IP to serve as an anchor point for the system, making it portable across networks.
- **Toggle Hosts Script**: Provides a mechanism to switch between normal and mobile hosts files, allowing for consistent DNS resolution when moving between networks.
- **NGINX Configuration**: Automatically configures NGINX with proper settings for Kubernetes API proxying and service ingress.
- **SSL Support**: Includes SSL certificate configuration for secure communication.
- **Removal with Confirmation**: Includes tasks to completely remove the container with user confirmation before taking action.

## Usage

### Deployment

To deploy the LXD NGINX-proxy container:

```bash
ansible-playbook lxd_nginx_proxy.yaml -K
```

### Removal

To remove the LXD NGINX-proxy container:

```bash
ansible-playbook lxd_nginx_proxy_remove.yaml
```

This will prompt for confirmation before removing the container and related configurations.

### Toggle Hosts - local DNS switcher

This script is used to quickly switch/toggle which local DNS (/etc/hosts OR /etc/hosts.mobile) the system will use.  Since the local system is intended to be mobile:

- static IP is not always possible
- we want to always use the same FQDN to acquire endpoints.  So we need to manipulate how DNS searches are completed

You can run ```sudo toggle-hosts.sh``` for details.

## Configuration

The role uses variables defined in `roles/lxd_nginx_proxy/defaults/main.yaml`. You can override these variables by:

1. Editing the defaults file directly
2. Passing variables via the command line with `-e` or `--extra-vars`
3. Creating a variables file and including it with `-e @vars_file.yaml`

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `var_lxd_nginx_proxy_container_name` | Name of the LXD container | `nginx-proxy` |
| `var_lxd_nginx_proxy_image` | Base image for the container | `ubuntu-minimal:24.04` |
| `var_lxd_nginx_proxy_dummy_interface_ip` | IP address for the dummy interface | `198.51.100.253/32` |
| `var_lxd_nginx_proxy_port_forwards` | Port forwarding configuration | See defaults file |

## Manual Installation

For manual installation instructions, please refer to [NOTES.md](NOTES.md).

## License

MIT

## Author

Your Name <your.email@example.com>
