#!/bin/sh
# Seed and prepare the persistent /htdocs volume, then start LinkStack.
set -eu

TARGET="/htdocs"
SEED="/htdocs-seed"

# Railway volumes start empty and shadow the files baked into the image.
# If the app isn't present yet (first deploy / fresh volume), seed it.
if [ ! -f "${TARGET}/version.json" ]; then
  echo "[railway-entrypoint] No LinkStack install in ${TARGET} — seeding from image..."
  mkdir -p "${TARGET}"
  cp -a "${SEED}/." "${TARGET}/"
  echo "[railway-entrypoint] Seed complete."
else
  echo "[railway-entrypoint] Existing LinkStack install detected — keeping it."
fi

# Railway mounts the volume as root; make sure the web user owns its data.
chown -R apache:apache "${TARGET}"

# Hand off to LinkStack's original entrypoint (passed in as CMD).
exec "$@"
