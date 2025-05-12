# Run NGINX-proxy in LXC for local Ingress

This document provides manual installation instructions for setting up an LXD container running NGINX-proxy for Kubernetes API aggregation and ingress. For automated deployment using Ansible, refer to the [README.md](README.md).

## Create Virtual Interface to be Anchor IP

This virtual interface (dummy interface) is required as the local system in portable. This means the main IP can/will change. This will cause issues with NGINX/Kubernetes configs. So we will create an anchor IP that will always be present on the system.
The IP set is from a special reserved block of IPs for documentation (RFC 5735). This is a good choice as the likelihood of an real-world IP conflict will be low and any local IP network (10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16) conflict will not exist.
But you can set the dummy-interface IP to almost anything you like.

Copy netplan file to system:
(source files are located within the Git from the './' location)

```shell
sudo cp ./global/netplan/30-dummy-interface.yaml /etc/netplan/30-dummy-interface.yaml
sudo chmod 600 /etc/netplan/30-dummy-interface.yaml
sudo netplan apply
```

## Pseudo Dynamic DNS Solution

Since this system is portable and intended to work within a local/private environment, we have a complex situation where we need DNS to always work with the same DNS records.
For example;
If my AI application has a A/CNAME record of "myai.abiwot-lab.com", then I always want to use the same DNS record to reach my application.
The issue can occur as the system travels between networks, the endpoint of the system could change, making DNS incorrect or difficult to manage.

We could always use the '/etc/hosts' to configure local DNS but who wants to really do that. For that reason, the basic concept is we create a "offline" hosts file and activate it when needed. So when your system is connected to your internal network (with a internal DNS server), you have the regular basic hosts file with DNS resolution occurring via the internal DNS server. When you are offline, now we activate our special hosts file to manipulate DNS records to ensure (from the end-user perspective) application endpoints have not changed.

How we accomplish is as you would expect. We have two hosts files:

- '/etc/hosts' = nothing special, entries as per normal
- '/etc/hosts.mobile' = where are override DNS values will be for offline mode

There is a simple script that allows you to quickly enable/disable which hosts file is active.
You will need to populate the '/etc/hosts.mobile' with your entries. This can be accomplished manually or via automation like a Git file (just modify the script to pull those entries)

Copy toggle-hosts.sh file to system:
(source files are located within the Git from the './' location)

```shell
sudo cp ./global/toggle-hosts/toggle-hosts.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/toggle-hosts.sh
```

### How to use toggle-hosts.sh

Now that the script resides in your /usr/local/bin, you can:

- help = ```sudo toggle-hosts.sh --help```
- initialize to create empty hosts file = ```sudo toggle-hosts.sh```
- status to know which hosts file is active = ```sudo toggle-hosts.sh status```
- enable/disable to activate the hosts file = ```sudo toggle-hosts.sh [enable|disable]```
- edit hosts.mobile in vi = ```sudo toggle-hosts.sh edit```


## Launch Container

```shell
lxc launch ubuntu-minimal:24.04 nginx-proxy
```

## LXC Port forward

```shell
lxc config device add nginx-proxy hostport443 proxy listen=tcp:0.0.0.0:443 connect=tcp:127.0.0.1:443
```

## Configure nginx-proxy Container

Exec into container:

```shell
lxc exec nginx-proxy /bin/bash
```

### Install Required Packages

```shell
sudo apt update && sudo apt -y upgrade
sudo apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring net-tools vim
```

### Configure NGINX repo

```shell
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | sudo tee /etc/apt/preferences.d/99nginx
```

```shell
sudo apt update
sudo apt install -y nginx
sudo apt-mark hold nginx
```

### Configure NGINX Application

#### Create Directories for NGINX

```shell
sudo mkdir -p /etc/pki/nginx/abiwot-lab
sudo mkdir -p /etc/nginx/conf.d/k8s/http
sudo mkdir -p /etc/nginx/conf.d/k8s/stream
```

#### Copy NGINX Configuration Files

Copy custom error files:
(source files are located within the Git from the './' location)

```shell
sudo cp ./global/nginx/custom_error/40x.html /usr/share/nginx/html/
sudo cp ./global/nginx/custom_error/50x.html /usr/share/nginx/html/
```

Copy NGINX configuration:
(source files are located within the Git from the './' location)

```shell
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.org
sudo cp ./online/etc/nginx/nginx.conf /etc/nginx/
```

Copy NGINX HTTP and STREAM configurations:
(source files are located within the Git from the './' location)

```shell
sudo cp ./online/etc/nginx.d/https_k8clstlocal01.conf /etc/nginx/conf.d/k8s/http/
sudo cp ./online/etc/nginx.d/stream_k8clstlocal01.conf /etc/nginx/conf.d/k8s/stream/
```

Copy SSL certificates:
(source files are located within the Git from the './' location)

```shell
sudo cp ./ssl/abiwot-lab.com/fullchain.pem /etc/pki/nginx/abiwot-lab/
sudo cp ./ssl/abiwot-lab.com/privkey.pem /etc/pki/nginx/abiwot-lab/
sudo chmod 700 /etc/pki/nginx/abiwot-lab
sudo chmod 600 /etc/pki/nginx/abiwot-lab/fullchain.pem
sudo chmod 600 /etc/pki/nginx/abiwot-lab/privkey.pem
```

### Validate and Activate NGINX Configurations

```shell
sudo systemctl restart nginx
sudo nginx -t
sudo nginx -s reload
```

## Removing the Container

To remove the container and clean up:

```shell
# Stop the container
lxc stop nginx-proxy

# Delete the container
lxc delete nginx-proxy

# Remove the dummy interface (optional)
sudo rm /etc/netplan/30-dummy-interface.yaml
sudo netplan apply

# Remove the toggle-hosts script (optional)
sudo rm /usr/local/bin/toggle-hosts.sh