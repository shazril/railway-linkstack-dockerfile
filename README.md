# Railway LinkStack Dockerfile

This repository contains a Docker-based setup for deploying the LinkStack PHP application on Railway or a similar container platform.

## Contents

- `Dockerfile` - Docker build instructions for the container.
- `entrypoint.sh` - Custom startup script that initializes the persistent volume with LinkStack application files if needed.

## Behavior

On container startup, `entrypoint.sh` does the following:

1. Checks whether the mounted persistent volume at `/htdocs` already contains `index.php`.
2. If the volume is empty or uninitialized, copies the LinkStack source files from `/app/linkstack-source/` into `/htdocs/`.
3. If the volume already contains application files, it skips the copy step.
4. Hands execution back to the original LinkStack container entrypoint via `exec /entrypoint.sh "$@"`.

## Notes

- Ensure the LinkStack source files are available at `/app/linkstack-source/` inside the image.
- Mount a persistent volume at `/htdocs` to preserve data and avoid re-initializing the app on every restart.
- Verify that `Dockerfile` contains the correct build steps for your intended base image and deployment flow.

## Usage

Build and run the container using your preferred Docker workflow, or deploy it through Railway with the repository as the service source.

```sh
docker build -t railway-linkstack .
docker run -v linkstack-data:/htdocs railway-linkstack
```

## Troubleshooting

- If LinkStack does not start, verify that `entrypoint.sh` is executable and that `/app/linkstack-source/` exists.
- Check logs for volume initialization messages from `entrypoint.sh`.
