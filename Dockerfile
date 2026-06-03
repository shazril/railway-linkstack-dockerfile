FROM linkstackorg/linkstack:latest

# 1. Elevate to root to set up permissions
USER root

# 2. Re-verify the web root directories are perfectly owned by Apache
RUN chown -R apache:apache /htdocs

# 3. Inform the Docker engine that /htdocs is a persistent boundary
VOLUME [ "/htdocs" ]

# 4. Drop back down to the container's native execution user context
USER apache