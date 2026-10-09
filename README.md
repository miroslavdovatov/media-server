# Automated Media Server & Disaster Recovery Pipeline

A self-hosted Jellyfin media server built around automation, security, monitoring, and disaster recovery.

The whole server can be rebuilt on a fresh Ubuntu VM with one Ansible playbook, with its state restored from encrypted off-site backups.

**Stack:** Ansible, Docker Compose, Jellyfin, Tailscale, Nginx Proxy Manager, DuckDNS, Let's Encrypt, Rclone, Cron, Uptime Kuma, Netdata

## Architecture

<img width="773" height="613" alt="Architecture diagram" src="https://github.com/user-attachments/assets/c3fc1650-bb69-44d6-bbf1-5891e1d5164e" />

## Features

- Server setup and recovery automated with Ansible
- Services run as Docker Compose stacks
- Private remote access through Tailscale
- HTTPS through Nginx Proxy Manager and Let's Encrypt, with a DuckDNS hostname
- Service monitoring with Uptime Kuma and system monitoring with Netdata
- Daily backups with Cron and Rclone, encrypted client-side before they reach Google Drive
- Automatic 7-day backup retention
- Disaster recovery onto a fresh Ubuntu VM

## Core Infrastructure

### Docker & Docker Compose

The services run in three Compose stacks: `npm`, `jellyfin`, and `monitoring`. They share an external Docker network called `proxy-tier`, which Ansible creates before starting the stacks. This lets Nginx Proxy Manager reach the other containers by name. Every container uses `restart: unless-stopped`, so the stack comes back after a reboot.

### Ansible

The playbook sets up the whole server over SSH. I chose Ansible because it is agentless, so it can configure a fresh Ubuntu VM without anything being installed on it first. The aim is a server that can be rebuilt from code instead of depending on manual configuration.

### Tailscale

Tailscale provides private network access to the server. SSH and the monitoring dashboards are reached over Tailscale instead of the public internet. Jellyfin has no published ports, so it can be used remotely without exposing the server directly.

### Rclone

Rclone handles the off-site backups. It uses an encrypted remote layered on top of Google Drive, so archives are encrypted on the server as they are uploaded and Drive only ever stores encrypted data.

## Routing & Services

### DuckDNS

DuckDNS provides a free dynamic DNS hostname, so the services are reached by name instead of an IP address that might change.

### Nginx Proxy Manager

Nginx Proxy Manager is the reverse proxy. It routes requests to the services by hostname and manages the Let's Encrypt certificates that provide HTTPS.

### Jellyfin

Jellyfin is the main application being hosted. It runs from the LinuxServer.io image, keeps its configuration in `docker/jellyfin/config`, and reads media from `/home/test/media`.

## Monitoring

**Uptime Kuma** checks that the hosted services are reachable and shows their current and historical uptime on a dashboard.

**Netdata** shows real-time metrics for CPU, RAM, disk, network, and Docker containers.

## Security

- **Private management access:** SSH and the monitoring dashboards are reached through Tailscale and are not exposed to the public internet.
- **Encrypted off-site backups:** Server state and configuration go to Google Drive through the encrypted Rclone remote.
- **Secrets:** The GitHub token is passed as an environment variable (`GH_TOKEN`) when the playbook runs. `.gitignore` keeps application data and backup archives out of the repository.

## Key Engineering Decisions

### Preserving the Tailscale identity

A rebuilt VM normally joins Tailscale as a new device, which means updating everything that depends on the old address. To avoid that, the backup includes Tailscale's state file:

```text
/var/lib/tailscale/tailscaled.state
```

During recovery, Ansible copies this file back and restarts the Tailscale service. The rebuilt server keeps its original Tailscale identity and address, so nothing that points at it needs to be reconfigured.

### Preserving file ownership and permissions

Nginx Proxy Manager's database and certificate files need the correct owners and permissions, or the container may fail to start. The restore tasks run as root (`become: yes`), and the Docker configuration is copied back with `cp -a`, which keeps the original ownership and permissions.

### Running backups as root with a user-level Rclone config

`backup.sh` has to run as root because it reads root-only files: Tailscale's state and the Docker data. Rclone looks for its config in the home directory of whoever runs it, and the config lives in the normal user's home. The script solves this by passing the config path explicitly with `--config`.

## Backup Strategy

`backup.sh` runs every day at 3am through Cron:

```text
Stage files -> Create archive -> Upload (encrypted by Rclone) -> Delete backups older than 7 days
```

It copies the Docker configuration and Tailscale state into a staging folder, packs them into a `.tar.gz` archive, and uploads the archive to Google Drive. The local temporary files are then removed, and backups older than 7 days are deleted from Drive. If the upload fails, the script stops, so old backups are only deleted after a new one has been uploaded.

The backup contains server state and configuration, not the media library. This keeps the uploads small.

## Disaster Recovery

To rebuild the server, run the playbook against a fresh Ubuntu VM. It:

1. Installs Docker, Docker Compose, Git, Rclone, and Tailscale.
2. Clones this repository onto the VM.
3. Copies in the Rclone config and downloads the latest backup from Google Drive.
4. Restores the Tailscale state and the Docker configuration, then restarts Tailscale.
5. Creates the `proxy-tier` network and starts the `npm`, `jellyfin`, and `monitoring` stacks.

The media library is not part of the backup, so restore it to `/home/test/media` separately.

## Prerequisites

- A fresh Ubuntu Server VM with SSH enabled and a user named `test` that has sudo access (the playbook uses `/home/test` paths)
- Ansible on the management machine, with this repository cloned there
- An `inventory.ini` that lists the VM in a `test_server` group
- An `rclone.conf` in the same directory as `playbook.yml`, containing the `gdrive-encrypted` remote
- At least one existing backup in that remote, because the playbook restores the latest one
- A GitHub token that can read the repository

## Deployment

1. Clone the repository:

```bash
git clone https://github.com/miroslavdovatov/media-server.git
cd media-server
```

2. Create `inventory.ini`:

```ini
[test_server]
<vm-address> ansible_user=test
```

3. Run the playbook:

```bash
GH_TOKEN="your-token" ansible-playbook -i inventory.ini playbook.yml
```

Add `--ask-become-pass` if sudo on the VM asks for a password. The playbook then does everything listed under Disaster Recovery.

## Project Goals

I built this to get hands-on experience with Linux server administration, Docker, networking and VPNs, reverse proxies and HTTPS, infrastructure automation, backup and disaster recovery, monitoring, and security. The goal was a server that is secure, reproducible, observable, and recoverable.
