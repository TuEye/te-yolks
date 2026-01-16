#!/bin/bash
set -euo pipefail

cd /home/container

# Make internal Docker IP address available to processes.
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# ---- Local Redis + MongoDB (same container) ----
: "${SCREEPS_SERVER_CMD:=npx screeps start}"
: "${CLI_HOST:=127.0.0.1}"
: "${CLI_PORT:=21026}"
: "${START_LOCAL_REDIS:=0}"
: "${START_LOCAL_MONGO:=0}"

REDIS_DIR="/home/container/data/redis"
MONGO_DBPATH="/home/container/data/mongo/db"
MONGO_LOGDIR="/home/container/data/mongo/log"

wait_for_tcp() {
  local host="$1" port="$2" tries="${3:-60}"
  for i in $(seq 1 "$tries"); do
    if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

start_redis() {
  mkdir -p "${REDIS_DIR}"
  echo "[init] Starting redis-server on 127.0.0.1:6379 ..."
  redis-server \
    --bind 127.0.0.1 \
    --port 6379 \
    --protected-mode yes \
    --dir "${REDIS_DIR}" \
    --appendonly yes \
    --pidfile "${REDIS_DIR}/redis-server.pid" \
    ${REDIS_EXTRA_ARGS:-} &
}

start_mongo() {
  mkdir -p "${MONGO_DBPATH}" "${MONGO_LOGDIR}"
  # Mongo kann recht aggressiv RAM nehmen; screepsmod-mongo weist darauf hin. 
  # Default hier konservativ, bei Bedarf per ENV überschreiben.
  : "${MONGO_WT_CACHE_GB:=0.25}"

  echo "[init] Starting mongod on 127.0.0.1:27017 (dbpath=${MONGO_DBPATH}) ..."
  mongod \
    --bind_ip 127.0.0.1 \
    --port 27017 \
    --dbpath "${MONGO_DBPATH}" \
    --logpath "${MONGO_LOGDIR}/mongod.log" \
    --logappend \
    --pidfilepath "/home/container/data/mongo/mongod.pid" \
    --wiredTigerCacheSizeGB "${MONGO_WT_CACHE_GB}" \
    ${MONGO_EXTRA_ARGS:-} &
}

if [ "${START_LOCAL_REDIS}" = "1" ]; then
  start_redis
  if ! wait_for_tcp 127.0.0.1 6379 60; then
    echo "[init] ERROR: Redis did not become ready on 127.0.0.1:6379" >&2
    exit 1
  fi
fi

if [ "${START_LOCAL_MONGO}" = "1" ]; then
  if command -v mongod >/dev/null 2>&1; then
    start_mongo
    if ! wait_for_tcp 127.0.0.1 27017 120; then
      echo "[init] ERROR: MongoDB did not become ready on 127.0.0.1:27017" >&2
      exit 1
    fi
  else
    echo "[init] WARNING: mongod not found. (Likely non-amd64 build). Use external MongoDB." >&2
  fi
fi

# Replace Startup Variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# If CLI Startup, start Server in Background
if echo "${MODIFIED_STARTUP}" | grep -Eq '(^|[[:space:]])screeps([[:space:]].*)?[[:space:]]cli([[:space:]]|$)'; then
  echo "[init] Detected CLI startup. Pre-starting Screeps server in background: ${SCREEPS_SERVER_CMD}"
  bash -lc "${SCREEPS_SERVER_CMD}" &
  SCREEPS_PID=$!

  echo "[init] Waiting for CLI on ${CLI_HOST}:${CLI_PORT} ..."
  if ! wait_for_tcp "${CLI_HOST}" "${CLI_PORT}" 120; then
    echo "[init] ERROR: CLI port not reachable. Killing server process ${SCREEPS_PID}."
    kill "${SCREEPS_PID}" 2>/dev/null || true
    exit 1
  fi
fi

# Run the Server (becomes PID 1; tini handles signal forwarding/reaping)
exec bash -lc "${MODIFIED_STARTUP}"
