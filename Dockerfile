# Deploy LinkStack on Railway with a persistent /htdocs volume + managed database.
#
# Why a custom image is needed:
#   The official linkstackorg/linkstack image bakes the whole app into /htdocs.
#   With plain Docker, a *named volume* mounted at /htdocs is auto-populated from
#   the image on first use, so it "just works". Railway volumes do NOT copy image
#   contents — they mount EMPTY and shadow the baked files, which breaks LinkStack
#   (its entrypoint reads /htdocs/version.json on boot and fails).
#
#   This image snapshots the baked app at build time; a wrapper entrypoint seeds
#   the volume on first deploy, wires the database from Railway env vars, runs
#   migrations, then hands off to the original entrypoint.

FROM linkstackorg/linkstack:latest

# Run as root so we can (a) fix ownership of the Railway volume, which is mounted
# as root, (b) bind port 80, and (c) run artisan. Apache still drops its worker
# processes to the unprivileged `apache` user (configured in the image's httpd.conf).
USER root

# The official image ships the Apache PHP module but not necessarily the PHP CLI,
# which our entrypoint needs to run `artisan` (migrate, key:generate). Install it.
RUN apk add --no-cache php83

# Fix mixed-content (http:// assets on an https page) behind Railway's TLS proxy.
# Loaded after ssl.conf thanks to the zz- prefix; conf.d/*.conf is auto-included.
COPY force-https.conf /etc/apache2/conf.d/zz-force-https.conf

# Snapshot the application shipped inside the image. The entrypoint copies this
# into the (initially empty) Railway volume on the first deploy only.
RUN cp -a /htdocs /htdocs-seed

# Our wrapper entrypoint runs first, then chains to the upstream entrypoint.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/railway-entrypoint.sh

ENTRYPOINT ["railway-entrypoint.sh"]
CMD ["docker-entrypoint.sh"]
