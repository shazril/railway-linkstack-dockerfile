#!/bin/sh
set -e

SOURCE_DIR="/app/linkstack-source"
TARGET_DIR="/htdocs"

echo "Checking persistent volume status at $TARGET_DIR..."

# Check for index.php inside the volume
if [ ! -f "$TARGET_DIR/index.php" ]; then
    echo "Volume is empty or uninitialized. Copying core LinkStack application files..."
    cp -a "$SOURCE_DIR/." "$TARGET_DIR/"
    echo "File copy complete."
else
    echo "Persistent volume already initialized with LinkStack files. Skipping copy."
fi

# Hand execution back to LinkStack's original entrypoint startup command
exec /entrypoint.sh "$@"