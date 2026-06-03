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

# 5. Keep permissions clean on internal paths
RUN chown -R apache:apache /app

# 6. Run the entrypoint script as root so it can modify the attached volume
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]