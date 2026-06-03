FROM linkstackorg/linkstack:latest

# 1. Elevate privileges to root to modify the system files
USER root

# 2. Create the backup directory and copy the source files
RUN mkdir -p /app/linkstack-source && \
    cp -a /htdocs/. /app/linkstack-source/

# 3. Copy your custom initialization script into the container
COPY entrypoint.sh /app/entrypoint.sh

# 4. Ensure the script has execution privileges
RUN chmod +x /app/entrypoint.sh

# 5. Fix ownership: Alpine uses 'apache:apache' instead of 'www-data:www-data'
RUN chown -R apache:apache /app /htdocs

# 6. Revert back to the container's original default user configuration automatically
USER apache

# 7. Override the default execution loop
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]