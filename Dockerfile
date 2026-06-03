FROM linkstackorg/linkstack:latest

# 1. Elevate privileges to root so we can modify the filesystem
USER root

# 2. Create the backup directory and copy the source files
RUN mkdir -p /app/linkstack-source && \
    cp -a /htdocs/. /app/linkstack-source/

# 3. Copy your custom initialization script into the container
COPY entrypoint.sh /app/entrypoint.sh

# 4. Ensure the script has execution permissions
RUN chmod +x /app/entrypoint.sh

# 5. Fix ownership: Make sure the webserver user (www-data) owns everything we just made
RUN chown -R www-data:www-data /app /htdocs

# 6. Drop back down to the default web user for runtime safety
USER www-data

# 7. Override the default entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]