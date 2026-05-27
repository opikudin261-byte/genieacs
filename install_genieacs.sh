#!/usr/bin/env bash
# install_genieacs.sh
# Skrip instalasi GenieACS lengkap dengan parameter penuh.
# Dirancang untuk Debian/Ubuntu dan mendukung berbagai macam ONU/TR-069 CPE.
# Gunakan: sudo bash install_genieacs.sh

set -euo pipefail
IFS=$'\n\t'

# Default parameter
GENIEACS_VERSION="2.11.0"
INSTALL_DIR="/opt/genieacs"
NODE_VERSION="18"
MONGO_HOST="127.0.0.1"
MONGO_PORT="27017"
MONGO_DB="genieacs"
REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"
REDIS_DB="0"
WEB_PORT="3000"
API_PORT="7557"
CWMP_PORT="7547"
BIND_ADDRESS="0.0.0.0"
LOG_LEVEL="info"
TZ="Asia/Jakarta"
SERVICE_USER="genieacs"
SERVICE_GROUP="genieacs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGO_SOURCE="${SCRIPT_DIR}/logo.png"
GENIEACS_ENV_FILE="/etc/genieacs/production.env"
PRODUCTION_CONFIG_FILE="/etc/genieacs/production.json"

usage() {
  cat <<EOF
Usage: sudo bash install_genieacs.sh [options]

Options:
  --version VERSION        GenieACS version (default: ${GENIEACS_VERSION})
  --install-dir PATH       Installation directory (default: ${INSTALL_DIR})
  --node-version VERSION   Node.js version (default: ${NODE_VERSION})
  --mongo-host HOST        MongoDB host (default: ${MONGO_HOST})
  --mongo-port PORT        MongoDB port (default: ${MONGO_PORT})
  --mongo-db DB            MongoDB database name (default: ${MONGO_DB})
  --redis-host HOST        Redis host (default: ${REDIS_HOST})
  --redis-port PORT        Redis port (default: ${REDIS_PORT})
  --redis-db DB            Redis DB index (default: ${REDIS_DB})
  --web-port PORT          GenieACS UI port (default: ${WEB_PORT})
  --api-port PORT          GenieACS NBI port (default: ${API_PORT})
  --cwmp-port PORT         GenieACS CWMP port (default: ${CWMP_PORT})
  --bind-address ADDR      Bind address (default: ${BIND_ADDRESS})
  --log-level LEVEL        Log level (default: ${LOG_LEVEL})
  --timezone TZ           Timezone (default: ${TZ})
  --logo-path PATH        Path to custom logo.png file (default: ${LOGO_SOURCE})
  -h, --help               Show this help and exit
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version) GENIEACS_VERSION="$2"; shift 2;;
      --install-dir) INSTALL_DIR="$2"; shift 2;;
      --node-version) NODE_VERSION="$2"; shift 2;;
      --mongo-host) MONGO_HOST="$2"; shift 2;;
      --mongo-port) MONGO_PORT="$2"; shift 2;;
      --mongo-db) MONGO_DB="$2"; shift 2;;
      --redis-host) REDIS_HOST="$2"; shift 2;;
      --redis-port) REDIS_PORT="$2"; shift 2;;
      --redis-db) REDIS_DB="$2"; shift 2;;
      --web-port) WEB_PORT="$2"; shift 2;;
      --api-port) API_PORT="$2"; shift 2;;
      --cwmp-port) CWMP_PORT="$2"; shift 2;;
      --bind-address) BIND_ADDRESS="$2"; shift 2;;
      --log-level) LOG_LEVEL="$2"; shift 2;;
      --timezone) TZ="$2"; shift 2;;
      --logo-path) LOGO_SOURCE="$2"; shift 2;;
      -h|--help) usage; exit 0;;
      *) echo "Unknown option: $1"; usage; exit 1;;
    esac
  done
}

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Skrip ini harus dijalankan sebagai root atau dengan sudo."
    exit 1
  fi
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
      echo "Distribusi tidak didukung oleh skrip ini. Hanya Debian/Ubuntu yang diuji."
      exit 1
    fi
  else
    echo "Tidak dapat mendeteksi OS.";
    exit 1
  fi
}

install_packages() {
  echo "[1/6] Memasang paket dependensi..."
  apt-get update
  apt-get install -y curl gnupg ca-certificates build-essential git python3 python3-venv python3-pip redis-server \
    mongodb-clients mongodb-server

  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
  apt-get install -y nodejs
}

create_user() {
  echo "[2/6] Membuat user service..."
  if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --home "$INSTALL_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
}

clone_genieacs() {
  echo "[3/6] Mengunduh GenieACS..."
  mkdir -p "$INSTALL_DIR"
  chown "$SERVICE_USER":"$SERVICE_GROUP" "$INSTALL_DIR"
  if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    git clone https://github.com/genieacs/genieacs.git "$INSTALL_DIR"
  fi
  pushd "$INSTALL_DIR" >/dev/null
  git fetch --all --tags
  git checkout "v${GENIEACS_VERSION}" || git checkout "${GENIEACS_VERSION}"
  npm install --production
  npm run build
  popd >/dev/null
}

create_directories() {
  echo "[4/6] Menyiapkan konfigurasi dan log..."
  mkdir -p /etc/genieacs /var/log/genieacs /var/lib/genieacs
  chown -R "$SERVICE_USER":"$SERVICE_GROUP" /etc/genieacs /var/log/genieacs /var/lib/genieacs
}

install_logo() {
  if [[ -f "$LOGO_SOURCE" ]]; then
    echo "[5/6] Menginstal logo GenieACS dari $LOGO_SOURCE..."
    local target_dir=""

    if [[ -d "$INSTALL_DIR/ui/public" ]]; then
      target_dir="$INSTALL_DIR/ui/public"
    elif [[ -d "$INSTALL_DIR/dist/ui" ]]; then
      target_dir="$INSTALL_DIR/dist/ui"
    elif [[ -d "$INSTALL_DIR/ui/src/assets" ]]; then
      target_dir="$INSTALL_DIR/ui/src/assets"
    elif [[ -d "$INSTALL_DIR/dist/ui/static" ]]; then
      target_dir="$INSTALL_DIR/dist/ui/static"
    fi

    if [[ -n "$target_dir" ]]; then
      cp -f "$LOGO_SOURCE" "$target_dir/logo.png"
      chown "$SERVICE_USER":"$SERVICE_GROUP" "$target_dir/logo.png"
      echo "Logo berhasil disalin ke $target_dir/logo.png"
    else
      echo "Peringatan: direktori logo UI tidak ditemukan di instalasi GenieACS. Logo tidak disalin."
    fi
  else
    echo "Logo tidak ditemukan di $LOGO_SOURCE, melewatkan instalasi logo."
  fi
}

create_env_file() {
  cat > "$GENIEACS_ENV_FILE" <<EOF
NODE_ENV=production
GENIEACS_CONFIG=${PRODUCTION_CONFIG_FILE}
GENIEACS_MONGODB_URL=mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}
GENIEACS_REDIS_URL=redis://${REDIS_HOST}:${REDIS_PORT}/${REDIS_DB}
GENIEACS_UI_PORT=${WEB_PORT}
GENIEACS_NBI_PORT=${API_PORT}
GENIEACS_CWMP_PORT=${CWMP_PORT}
GENIEACS_BIND_ADDRESS=${BIND_ADDRESS}
GENIEACS_LOG_LEVEL=${LOG_LEVEL}
TZ=${TZ}
EOF
  chown "$SERVICE_USER":"$SERVICE_GROUP" "$GENIEACS_ENV_FILE"
  chmod 640 "$GENIEACS_ENV_FILE"
}

create_production_config() {
  cat > "$PRODUCTION_CONFIG_FILE" <<EOF
{
  "http": {
    "port": ${CWMP_PORT},
    "bind": "${BIND_ADDRESS}",
    "timeout": 60000,
    "maxHttpBodyLength": 10485760
  },
  "cwmp": {
    "verify": false,
    "url": "/xml",
    "keepAliveTimeout": 65000,
    "responseTimeout": 60000,
    "requestTimeout": 180000,
    "retries": 3,
    "retryDelay": 2000
  },
  "soap": {
    "forceMessageId": true,
    "maxMultipartMemory": 104857600
  },
  "acs": {
    "linger": 30000,
    "sessionTimeout": 900000
  },
  "provisioning": {
    "autoConfig": true,
    "autoSync": true,
    "enableUploads": true,
    "reporting": true
  },
  "device": {
    "defaultProfile": "default",
    "allowUnknown": true,
    "forceUnknown": false
  }
}
EOF
  chown "$SERVICE_USER":"$SERVICE_GROUP" "$PRODUCTION_CONFIG_FILE"
  chmod 640 "$PRODUCTION_CONFIG_FILE"
}

create_systemd_services() {
  echo "[5/6] Membuat service systemd..."
  cat > /etc/systemd/system/genieacs-cwmp.service <<EOF
[Unit]
Description=GenieACS CWMP
After=network.target redis-server.service mongodb.service
Requires=redis-server.service mongodb.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
EnvironmentFile=${GENIEACS_ENV_FILE}
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node ${INSTALL_DIR}/dist/cwmp.js
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=genieacs-cwmp

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/genieacs-nbi.service <<EOF
[Unit]
Description=GenieACS NBI
After=network.target redis-server.service mongodb.service
Requires=redis-server.service mongodb.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
EnvironmentFile=${GENIEACS_ENV_FILE}
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node ${INSTALL_DIR}/dist/nbi.js
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=genieacs-nbi

[Install]
WantedBy=multi-user.target
EOF

  cat > /etc/systemd/system/genieacs-ui.service <<EOF
[Unit]
Description=GenieACS UI
After=network.target redis-server.service mongodb.service
Requires=redis-server.service mongodb.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
EnvironmentFile=${GENIEACS_ENV_FILE}
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/node ${INSTALL_DIR}/dist/ui.js
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=genieacs-ui

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable genieacs-cwmp.service genieacs-nbi.service genieacs-ui.service
}

start_services() {
  echo "[6/6] Memulai GenieACS dan dependensi..."
  systemctl restart redis-server mongodb.service
  systemctl restart genieacs-cwmp.service genieacs-nbi.service genieacs-ui.service
  systemctl status genieacs-ui.service --no-pager
}

main() {
  parse_args "$@"
  check_root
  detect_os
  install_packages
  create_user
  clone_genieacs
  create_directories
  create_env_file
  create_production_config
  create_systemd_services
  install_logo
  start_services
  printf '\nInstalasi GenieACS selesai. Akses UI di http://%s:%s\n' "${BIND_ADDRESS}" "${WEB_PORT}"
  echo "Untuk menambahkan profiling ONU, gunakan GenieACS provisioning profiles dan device templates."
}

main "$@"
