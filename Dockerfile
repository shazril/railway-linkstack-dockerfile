FROM linkstackorg/linkstack:latest

# 1. Elevate privileges to root
USER root

# 2. Install bash so LinkStack's native entrypoint script can read it
RUN apk add --no-cache bash

# 3. Create our backup directory and copy the source files
RUN mkdir -p /app/linkstack-source && \
    cp -a /htdocs/. /app/linkstack-source/

# 4. Copy our custom initialization script into the container
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 5. Fix ownership across paths
RUN chown -R apache:apache /app /htdocs

# 6. Execute our wrapper script as root so it can fix the cloud volume permissions at boot
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]