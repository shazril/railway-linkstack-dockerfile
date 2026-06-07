#!/bin/sh
# Seed the persistent /htdocs volume, wire up the database from Railway env vars,
# run migrations, then start LinkStack.
set -eu

HTDOCS="/htdocs"
SEED="/htdocs-seed"
ENV_FILE="${HTDOCS}/.env"

log() { echo "[railway-entrypoint] $*"; }

# Pick a PHP CLI binary (the image uses php83; `php` may not be symlinked).
if command -v php >/dev/null 2>&1; then
  PHP="php"
elif command -v php83 >/dev/null 2>&1; then
  PHP="php83"
else
  log "WARNING: no PHP CLI found; artisan steps will be skipped."
  PHP=""
fi

# --- 1. Seed the volume on first boot ------------------------------------
if [ ! -f "${HTDOCS}/version.json" ]; then
  log "No LinkStack install in ${HTDOCS} — seeding from image..."
  mkdir -p "${HTDOCS}"
  cp -a "${SEED}/." "${HTDOCS}/"
  log "Seed complete."
else
  log "Existing LinkStack install detected — keeping it."
fi

# Make sure an .env exists (Laravel reads its config from here).
if [ ! -f "${ENV_FILE}" ]; then
  if [ -f "${HTDOCS}/.env.example" ]; then
    log "No .env found — creating one from .env.example."
    cp "${HTDOCS}/.env.example" "${ENV_FILE}"
  else
    log "No .env / .env.example — creating an empty .env."
    : > "${ENV_FILE}"
  fi
fi

cd "${HTDOCS}"

# --- helper: set or replace KEY="value" in .env --------------------------
set_env() {
  _k="$1"; _v="$2"
  _e=$(printf '%s' "${_v}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')   # escape \ and "
  if grep -qE "^${_k}=" "${ENV_FILE}"; then
    _tmp=$(mktemp)
    awk -v k="${_k}" -v v="\"${_e}\"" '
      index($0, k"=")==1 { print k"="v; next }
      { print }
    ' "${ENV_FILE}" > "${_tmp}"
    cat "${_tmp}" > "${ENV_FILE}"
    rm -f "${_tmp}"
  else
    printf '%s="%s"\n' "${_k}" "${_e}" >> "${ENV_FILE}"
  fi
}

# --- 2. Resolve DB settings ----------------------------------------------
# Priority: explicit DB_* (e.g. Railway reference variables)
#           > Railway MySQL plugin (MYSQL*) > Railway Postgres plugin (PG*).
DB_CONNECTION="${DB_CONNECTION:-}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-}"
DB_DATABASE="${DB_DATABASE:-}"
DB_USERNAME="${DB_USERNAME:-}"
DB_PASSWORD="${DB_PASSWORD:-}"

if [ -z "${DB_HOST}" ] && [ -n "${MYSQLHOST:-}" ]; then
  log "Mapping Railway MySQL plugin variables -> DB_*"
  DB_CONNECTION="mysql"
  DB_HOST="${MYSQLHOST}"
  DB_PORT="${MYSQLPORT:-3306}"
  DB_DATABASE="${MYSQLDATABASE:-railway}"
  DB_USERNAME="${MYSQLUSER:-root}"
  DB_PASSWORD="${MYSQLPASSWORD:-}"
elif [ -z "${DB_HOST}" ] && [ -n "${PGHOST:-}" ]; then
  log "Mapping Railway PostgreSQL plugin variables -> DB_*"
  DB_CONNECTION="pgsql"
  DB_HOST="${PGHOST}"
  DB_PORT="${PGPORT:-5432}"
  DB_DATABASE="${PGDATABASE:-railway}"
  DB_USERNAME="${PGUSER:-postgres}"
  DB_PASSWORD="${PGPASSWORD:-}"
fi

# Persist whatever we resolved into .env so the app AND the web UI use it.
if [ -n "${DB_HOST}" ]; then
  [ -n "${DB_CONNECTION}" ] || DB_CONNECTION="mysql"
  log "Configuring database: ${DB_CONNECTION} @ ${DB_HOST}:${DB_PORT}/${DB_DATABASE}"
  set_env "DB_CONNECTION" "${DB_CONNECTION}"
  set_env "DB_HOST"       "${DB_HOST}"
  set_env "DB_PORT"       "${DB_PORT}"
  set_env "DB_DATABASE"   "${DB_DATABASE}"
  set_env "DB_USERNAME"   "${DB_USERNAME}"
  set_env "DB_PASSWORD"   "${DB_PASSWORD}"
else
  log "No external DB env vars found — keeping existing .env DB settings."
  DB_CONNECTION="$(grep -E '^DB_CONNECTION=' "${ENV_FILE}" | head -n1 | cut -d= -f2- | tr -d '\"' || true)"
fi

# --- 3. Run artisan setup steps ------------------------------------------
if [ -n "${PHP}" ]; then
  # Ensure an APP_KEY exists (only generate when truly empty, to avoid
  # invalidating data on an existing install).
  _appkey="$(grep -E '^APP_KEY=' "${ENV_FILE}" | head -n1 || true)"
  case "${_appkey}" in
    ""|"APP_KEY="|'APP_KEY=""')
      log "Generating APP_KEY..."
      ${PHP} artisan key:generate --force || log "key:generate failed (continuing)."
      ;;
    *) : ;;
  esac

  # Drop stale cached config that may live in the volume, so .env is re-read.
  ${PHP} artisan config:clear >/dev/null 2>&1 || true
  ${PHP} artisan cache:clear  >/dev/null 2>&1 || true

  # Wait for an external DB to accept connections (Railway private networking
  # and DB cold-start can lag a few seconds behind the app).
  if [ -n "${DB_HOST}" ] && [ "${DB_CONNECTION}" != "sqlite" ]; then
    log "Waiting for database to accept connections..."
    i=1
    until DB_CONNECTION="${DB_CONNECTION}" DB_HOST="${DB_HOST}" DB_PORT="${DB_PORT}" \
          DB_DATABASE="${DB_DATABASE}" DB_USERNAME="${DB_USERNAME}" DB_PASSWORD="${DB_PASSWORD}" \
          ${PHP} -r '
            $drv = getenv("DB_CONNECTION")==="pgsql" ? "pgsql" : "mysql";
            $dsn = sprintf("%s:host=%s;port=%s;dbname=%s",
                           $drv, getenv("DB_HOST"), getenv("DB_PORT"), getenv("DB_DATABASE"));
            try { new PDO($dsn, getenv("DB_USERNAME"), getenv("DB_PASSWORD"),
                          [PDO::ATTR_TIMEOUT => 3]); }
            catch (Throwable $e) { exit(1); }
          ' 2>/dev/null
    do
      if [ "${i}" -ge 30 ]; then
        log "DB still unreachable after ~$((i*2))s — continuing (migrate may fail)."
        break
      fi
      log "  ...not ready (attempt ${i}); retrying in 2s"
      i=$((i+1)); sleep 2
    done
  fi

  # For sqlite, make sure the database file exists before migrating.
  if [ "${DB_CONNECTION}" = "sqlite" ]; then
    mkdir -p "${HTDOCS}/database"
    [ -f "${HTDOCS}/database/database.sqlite" ] || : > "${HTDOCS}/database/database.sqlite"
  fi

  log "Running database migrations..."
  ${PHP} artisan migrate --force || log "migrate reported an error (see logs above)."
fi

# --- 4. Fix ownership (Railway mounts the volume as root) ----------------
chown -R apache:apache "${HTDOCS}"

# --- 5. Hand off to LinkStack's original entrypoint ----------------------
log "Starting LinkStack..."
exec "$@"
