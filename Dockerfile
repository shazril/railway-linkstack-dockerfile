# Define the source backup directory and the destination volume path
SOURCE_DIR="/app/linkstack-source"
TARGET_DIR="/htdocs"

echo "Checking persistent volume status at $TARGET_DIR..."

# If the target directory is empty (or missing critical files like index.php)
if [ ! -f "$TARGET_DIR/index.php" ]; then
    echo "Volume is empty or uninitialized. Copying core LinkStack application files..."
    # Copy all files including hidden ones from our source backup to the volume
    cp -a "$SOURCE_DIR/." "$TARGET_DIR/"
    echo "File copy complete."
else
    echo "Persistent volume already initialized with LinkStack files. Skipping copy."
fi

# Hand execution back to LinkStack's original container entrypoint startup command
exec /entrypoint.sh "$@"
