#!/bin/sh
set -e

SOURCE_DIR="/app/linkstack-source"
TARGET_DIR="/htdocs"

echo "Checking persistent volume ownership and status at $TARGET_DIR..."

# 1. Force the root-owned cloud volume to be owned by apache
chown -R apache:apache "$TARGET_DIR"

# 2. Check if the volume is missing core files
if [ ! -f "$TARGET_DIR/index.php" ]; then
    echo "Volume is empty or uninitialized. Copying core LinkStack application files..."
    cp -a "$SOURCE_DIR/." "$TARGET_DIR/"
    # Enforce correct ownership on newly copied files
    chown -R apache:apache "$TARGET_DIR"
    echo "File copy complete."
else
    echo "Persistent volume already initialized with LinkStack files. Skipping copy."
fi

echo "Handing control over to the main app container..."
# 3. FIX: Point precisely to the image's original entrypoint script
exec /docker-entrypoint.sh "$@"