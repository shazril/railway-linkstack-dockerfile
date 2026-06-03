FROM linkstackorg/linkstack:latest

# Move the pre-baked application files to a backup source directory
RUN mkdir -p /app/linkstack-source && \
    cp -a /htdocs/. /app/linkstack-source/

# Copy our custom initialization script into the container
COPY entrypoint.sh /app/entrypoint.sh

# Ensure the script has execution permissions
RUN chmod +x /app/entrypoint.sh

# Override the default entrypoint execution to run our check script first
ENTRYPOINT ["/app/entrypoint.sh"]
