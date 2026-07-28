#!/bin/bash
set -e

SOURCE_DIR="/home/test/media-server/docker"
BACKUP_DIR="/tmp/docker-backups"
DATE=$(date +%Y-%m-%d_%H-%M)
ARCHIVE_NAME="docker_state_${DATE}.tar.gz"
REMOTE="gdrive-encrypted:"
CONFIG_FILE="/home/test/.config/rclone/rclone.conf"

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$SOURCE_DIR" .

rclone --config "$CONFIG_FILE" copy "$BACKUP_DIR/$ARCHIVE_NAME" "$REMOTE"

rm -rf "$BACKUP_DIR"

rclone --config "$CONFIG_FILE" delete --min-age 7d "$REMOTE"
