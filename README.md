# Automated Media Server & Disaster Recovery Pipeline

A self-hosted Jellyfin media server designed with automation, security, monitoring, and disaster recovery in mind.

The entire server can be rebuilt from a fresh Ubuntu VM using Ansible, with application state restored from encrypted off-site backups.

Core technologies used: Ansible - Docker Compose - Tailscale - Nginx Proxy Manager - Rclone - Uptime Kuma - Netdata

## Architecture
<img width="773" height="613" alt="Diagram" src="https://github.com/user-attachments/assets/c3fc1650-bb69-44d6-bbf1-5891e1d5164e" />


## Features

* **Fully automated deployment** with Ansible
* **Containerized services** using Docker Compose
* **Private remote access** through Tailscale
* **HTTPS** through Nginx Proxy Manager and Let's Encrypt
* **Dynamic DNS** through DuckDNS
* **Service monitoring** with Uptime Kuma
* **System monitoring** with Netdata
* **Automated daily backups** using Cron and Rclone
* **Client-side encrypted off-site backups**
* **Automated backup retention** of 7 days
* **Disaster recovery** from a fresh Ubuntu VM

## Core Infrastructure

### Docker & Docker Compose

Docker provides isolated containers for the services and Docker Compose manages the complete application stack.

This makes the services portable and simplifies deployment and recovery.

### Ansible

Ansible is used to automate the complete server deployment.

I chose it because it's agentless and can configure a fresh Ubuntu server remotely over SSH without requiring a separate agent to be installed first.

The goal is to make the server reproducible rather than relying on manual configuration.

### Tailscale

Tailscale provides private network access to the server.

SSH and monitoring interfaces are not exposed to the public internet and are instead accessible only through the private Tailscale network.

This also allows Jellyfin to be accessed remotely without directly exposing the server's ports.

### Rclone

I used Rclone to handle the off-site backup process.

Backup archives are encrypted locally before being uploaded to Google Drive.

---

## Routing & Services

### DuckDNS

DuckDNS provides a free dynamic DNS hostname for the server.

This lets the services be accessed through a hostname rather than relying on a potentially changing IP address.

### Nginx Proxy Manager

Handles hostname-based routing and acts as the reverse proxy for the services. 
It automatically manages HTTPS certificates through Let's Encrypt providing encrypted HTTPS connections to the services.

### Jellyfin

Jellyfin is the primary application being hosted.

It provides the media server functionality while also serving as the main workload for the infrastructure surrounding it.

---

## Monitoring

### Uptime Kuma

This monitors the availability of the hosted services.

It checks whether the services are reachable and provides a dashboard showing their current and historical uptime.

### Netdata

Netdata provides real-time system and container metrics.

It is used to monitor resources such as:

* CPU usage
* RAM usage
* Disk usage
* Network activity
* Docker containers

---

## Security

### No Public Management Ports

SSH and monitoring dashboards are accessible only through the Tailscale network.

They are not exposed directly to the public internet.

### Encrypted Off-Site Storage

Server state and configuration are backed up to Google Drive using Rclone.

The backup archives are encrypted locally before being uploaded.

### Secret Isolation

Sensitive credentials such as API keys and GitHub tokens are supplied through environment variables rather than being stored directly in version control.

---

## Key Engineering Decisions

### Preserving the Tailscale Identity

Rebuilding the VM normally results in a new Tailscale identity, which would require updating the server's network configuration and routing.

To avoid this, the backup process includes:

```text
/var/lib/tailscale/tailscaled.state
```

Ansible restores this state before starting the Tailscale service, allowing the rebuilt server to retain its existing Tailscale identity.

This means services depending on the server's existing Tailscale address do not need to be reconfigured after recovery.

---

### Preserving Nginx Proxy Manager Permissions

Nginx Proxy Manager's database and SSL certificate files require the correct Linux ownership and permissions.

Restoring these files without preserving their permissions can prevent the container from starting correctly.

The Ansible restore process therefore uses elevated privileges where required:

```yaml
become: yes
```

This ensures restored files retain the permissions required by the services.

---

### Handling Sudo and Rclone User Context

The backup process requires elevated privileges to access protected Docker and Tailscale state.

However, Rclone is configured for the normal user account rather than root.

Running Rclone directly as root would prevent it from accessing the user's Rclone configuration.

The backup script handles this by:

- Performing the privileged archive operation as root.
- Switching back to the normal user for the Rclone upload.
- Uploading the encrypted archive to Google Drive.

This allows the backup to access protected system files without running the cloud-storage client as root.

---

## Backup Strategy

A `backup.sh` script runs automatically every day at 3am through Cron.

The process is:

```text
Docker & Tailscale state
          │
          ▼
     Create archive
          │
          ▼
   Client-side encryption
          │
          ▼
    Upload via Rclone
          │
          ▼
      Google Drive
          │
          ▼
 Delete backups older
       than 7 days
```

The backup contains server state and configuration, not the media library itself.

This keeps the backup focused on the information required to reconstruct the infrastructure without uploading large media files.

---

## Disaster Recovery

The intended recovery workflow is:

```text
Fresh Ubuntu VM
       │
       ▼
SSH access
       │
       ▼
Run Ansible
       │
       ▼
Install & configure infrastructure
       │
       ▼
Restore encrypted backup
       │
       ▼
Start Docker services
       │
       ▼
Server operational
```

The objective is to make recovery reproducible and minimize manual configuration.

---

## Prerequisites

Before deployment, you need:

* A fresh Ubuntu Server VM
* OpenSSH configured
* Ansible installed on the host machine
* This repository cloned to the management machine
* An `inventory.ini` file containing the target VM
* SSH access to the VM

## Deployment

- Clone the repository:

```bash
git clone https://github.com/miroslavdovatov/media-server.git
cd media-server
```

- Run the Ansible playbook:

```bash
GH_TOKEN="your-token" ansible-playbook -i inventory.ini playbook.yml
```

Ansible then handles the server configuration and deployment.

## Project Goals

This project was built to gain practical experience with:

* Linux server administration
* Docker and containerization
* Networking and VPNs
* Reverse proxies and HTTPS
* Infrastructure automation
* Backup and disaster recovery
* System monitoring
* Security
* Reproducible infrastructure

The goal is to build an infrastructure stack that is secure, reproducible, observable, and recoverable.
