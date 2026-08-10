#!/bin/bash
set -e

SOURCE_DIR="/home/test/media-server/docker"
TAILSCALE_STATE="/var/lib/tailscale/tailscaled.state"
BACKUP_DIR="/tmp/docker-backups"
STAGE_DIR="/tmp/backup-stage"
DATE=$(date +%Y-%m-%d_%H-%M)
ARCHIVE_NAME="docker_state_${DATE}.tar.gz"
REMOTE="gdrive-encrypted:"
CONFIG_FILE="/home/test/.config/rclone/rclone.conf"

mkdir -p "$BACKUP_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/docker" "$STAGE_DIR/tailscale"

cp -a "$SOURCE_DIR/." "$STAGE_DIR/docker/"

if [ -f "$TAILSCALE_STATE" ]; then
    cp -a "$TAILSCALE_STATE" "$STAGE_DIR/tailscale/"
else
    echo "Tailscale state file not found at $TAILSCALE_STATE"
fi

tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$STAGE_DIR" .

rclone --config "$CONFIG_FILE" copy "$BACKUP_DIR/$ARCHIVE_NAME" "$REMOTE"

rm -rf "$BACKUP_DIR" "$STAGE_DIR"

rclone --config "$CONFIG_FILE" delete --min-age 7d "$REMOTE"
