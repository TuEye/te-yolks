#!/bin/bash
set -euo pipefail

cd /home/container

# Make internal Docker IP address available to processes.
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Ensure pyenv/python PATH is available even if a runtime orchestrator overrides PATH.
# Also avoids relying on login-shell behavior that may rewrite PATH.
export PYENV_ROOT="${PYENV_ROOT:-/opt/pyenv}"
export NVM_DIR="${NVM_DIR:-/opt/nvm}"
export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${NVM_DIR}/current/bin:${PATH}"

# Ensure nvm-managed Node.js is available for all users (non-login shells included).
if [ -s "${NVM_DIR}/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "${NVM_DIR}/nvm.sh"
  nvm use --silent default >/dev/null 2>&1 || true
fi

# ---- Variables and Defaults ----
: "${SCREEPS_SERVER_CMD:=npx screeps start}"
: "${SCREEPS_LAUNCHER_SERVER_CMD:=./screeps-launcher}"
: "${CLI_HOST:=127.0.0.1}"
: "${CLI_PORT:=21026}"
: "${START_LOCAL_REDIS:=0}"
: "${START_LOCAL_MONGO:=0}"
: "${WAIT_FOR_CLI_TIMEOUT:=300}"
: "${START_SCREEPS_BACKGROUND:=0}"
: "${START_SCREEPS_LAUNCHER_BACKGROUND:=0}"

# Allow host/port override from outside
REDIS_HOST="127.0.0.1"
: "${REDIS_PORT:=6379}"
MONGO_HOST="127.0.0.1"
: "${MONGO_PORT:=27017}"

# Cleanup flags (default true)
# Accepts: 1/true/yes/on (case-insensitive)
: "${CLEANUP_REDIS_LOGS:=1}"
: "${CLEANUP_MONGODB_LOGS:=1}"

REDIS_DIR="/home/container/data/redis"
MONGO_DBPATH="/home/container/data/mongo/db"
MONGO_LOGDIR="/home/container/data/mongo/log"

is_true() {
  # Accepts: 1/true/yes/on (case-insensitive)
  case "${1,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

wait_for_tcp() {
  local host="$1" port="$2" tries="${3:-60}"
  for _ in $(seq 1 "$tries"); do
    if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

start_redis() {
  mkdir -p "${REDIS_DIR}"
  
  local redis_logfile="${REDIS_DIR}/redis.log"
  if is_true "${CLEANUP_REDIS_LOGS}"; then
    rm -f "${redis_logfile}" 2>/dev/null || true
  fi
  
  echo "[init] Starting redis-server on ${REDIS_HOST}:${REDIS_PORT} ..."
  redis-server \
    --bind "${REDIS_HOST}" \
    --port "${REDIS_PORT}" \
    --protected-mode yes \
    --dir "${REDIS_DIR}" \
    --appendonly yes \
    --logfile "${redis_logfile}" \
    --pidfile "${REDIS_DIR}/redis-server.pid" \
    ${REDIS_EXTRA_ARGS:-} &
}

start_mongo() {
  mkdir -p "${MONGO_DBPATH}" "${MONGO_LOGDIR}"
  
  local mongo_logfile="${MONGO_LOGDIR}/mongod.log"
  if is_true "${CLEANUP_MONGODB_LOGS}"; then
    rm -f "${mongo_logfile}" 2>/dev/null || true
  fi
  
  # Mongo can consume RAM aggressively; keep default conservative.
  : "${MONGO_WT_CACHE_GB:=0.25}"

  echo "[init] Starting mongod on ${MONGO_HOST}:${MONGO_PORT} (dbpath=${MONGO_DBPATH}) ..."
  mongod \
    --bind_ip "${MONGO_HOST}" \
    --port "${MONGO_PORT}" \
    --dbpath "${MONGO_DBPATH}" \
    --logpath "${mongo_logfile}" \
    --logappend \
    --pidfilepath "/home/container/data/mongo/mongod.pid" \
    --wiredTigerCacheSizeGB "${MONGO_WT_CACHE_GB}" \
    ${MONGO_EXTRA_ARGS:-} &
}

ensure_python2() {
  local py2_bin="/usr/local/bin/python2"

  if [[ ! -x "${py2_bin}" ]]; then
    local pyenv_root="${PYENV_ROOT:-/opt/pyenv}"
    local py2_ver="${PYTHON2_VERSION:-2.7.18}"
    local candidate="${pyenv_root}/versions/${py2_ver}/bin/python"
    if [[ -x "${candidate}" ]]; then
      py2_bin="${candidate}"
    fi
  fi

  if [[ ! -x "${py2_bin}" ]]; then
    echo "[init] ERROR: Python 2 interpreter not found. Expected /usr/local/bin/python2 or \$PYENV_ROOT/versions/\$PYTHON2_VERSION/bin/python." >&2
    return 1
  fi

  # Help node-gyp find Python 2
  export npm_config_python="${py2_bin}"
  export PYTHON="${py2_bin}"
  export NODE_GYP_FORCE_PYTHON="${py2_bin}"

  echo "[init] Using Python for node-gyp: $(${py2_bin} -V 2>&1) @ ${py2_bin}"

  # Some toolchains expect libpython on the loader path; keep it as a safe fallback.
  local resolved
  resolved=$(readlink -f "${py2_bin}" 2>/dev/null || true)
  if [[ -n "${resolved}" ]]; then
    local prefix
    prefix=$(dirname "$(dirname "${resolved}")")
    if [[ -d "${prefix}/lib" ]]; then
      export LD_LIBRARY_PATH="${prefix}/lib:${LD_LIBRARY_PATH:-}"
    fi
  fi
}

if [ "${START_LOCAL_REDIS}" = "1" ]; then
  start_redis
  if ! wait_for_tcp "${REDIS_HOST}" "${REDIS_PORT}" 60; then
    echo "[init] ERROR: Redis did not become ready on ${REDIS_HOST}:${REDIS_PORT}" >&2
    exit 1
  fi
fi

if [ "${START_LOCAL_MONGO}" = "1" ]; then
  if command -v mongod >/dev/null 2>&1; then
    start_mongo
    if ! wait_for_tcp "${MONGO_HOST}" "${MONGO_PORT}" 120; then
      echo "[init] ERROR: MongoDB did not become ready on ${MONGO_HOST}:${MONGO_PORT}" >&2
      exit 1
    fi
  else
    echo "[init] WARNING: mongod not found. (Likely non-amd64 build). Use external MongoDB." >&2
  fi
fi

# Replace Startup Variables
MODIFIED_STARTUP=$(printf '%s' "${STARTUP:-}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
printf '%s\n' ":/home/container$ ${MODIFIED_STARTUP}"

# Background start (explicit via env vars)
PRESTART_CMD=""

if is_true "${START_SCREEPS_BACKGROUND}" && is_true "${START_SCREEPS_LAUNCHER_BACKGROUND}"; then
  echo "[init] ERROR: Both START_SCREEPS_BACKGROUND and START_SCREEPS_LAUNCHER_BACKGROUND are enabled; only one can be true." >&2
  exit 1
fi

if is_true "${START_SCREEPS_BACKGROUND}"; then
  PRESTART_CMD="${SCREEPS_SERVER_CMD}"
elif is_true "${START_SCREEPS_LAUNCHER_BACKGROUND}"; then
  PRESTART_CMD="${SCREEPS_LAUNCHER_SERVER_CMD}"

  ensure_python2

  # --- isolated-vm Build-Fix: C++14 + <utility> enforce ---
  export CXXFLAGS="${CXXFLAGS:-} -std=gnu++14 -include utility -include limits"
fi

if [[ -n "${PRESTART_CMD}" ]]; then
  echo "[init] Pre-starting server in background: ${PRESTART_CMD}"
  bash -c "${PRESTART_CMD}" &
  SCREEPS_PID=$!

  echo "[init] Waiting for CLI on ${CLI_HOST}:${CLI_PORT} ..."
  if ! wait_for_tcp "${CLI_HOST}" "${CLI_PORT}" "${WAIT_FOR_CLI_TIMEOUT}"; then
    echo "[init] ERROR: CLI port not reachable. Killing server process ${SCREEPS_PID}." >&2
    kill "${SCREEPS_PID}" 2>/dev/null || true
    exit 1
  fi
fi

# Run the Server (becomes PID 1; tini handles signal forwarding/reaping)
# Avoid login shell (-l) to prevent /etc/profile from overwriting PATH and other env.
exec bash -c "${MODIFIED_STARTUP}"
