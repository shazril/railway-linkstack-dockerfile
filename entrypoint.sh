#!/bin/sh
set -e

SOURCE_DIR="/app/linkstack-source"
TARGET_DIR="/htdocs"

echo "Checking persistent volume ownership and status at $TARGET_DIR..."

# 1. Take ownership of the mounted cloud volume
chown -R apache:apache "$TARGET_DIR"

# 2. Check if the volume is missing core files
if [ ! -f "$TARGET_DIR/index.php" ]; then
    echo "Volume is empty or uninitialized. Copying core LinkStack application files..."
    cp -a "$SOURCE_DIR/." "$TARGET_DIR/"
    chown -R apache:apache "$TARGET_DIR"
    echo "File copy complete."
else
    echo "Persistent volume already initialized with LinkStack files. Skipping copy."
fi

echo "Handing control over to the main app container using bash..."
# 3. Force execution through bash (which we just installed via the Dockerfile)
exec bash /entrypoint.sh "$@"