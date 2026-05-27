#!/usr/bin/env bash
# uninstall_genieacs.sh
# Skrip uninstall GenieACS bersih, hapus semua jejak GenieACS kecuali dependensi sistem.
# Gunakan: sudo bash uninstall_genieacs.sh

set -euo pipefail
IFS=$'\n\t'

INSTALL_DIR="/opt/genieacs"
CONFIG_DIR="/etc/genieacs"
LOG_DIR="/var/log/genieacs"
DATA_DIR="/var/lib/genieacs"
SERVICE_USER="genieacs"
SERVICE_GROUP="genieacs"
SYSTEMD_UNITS=(genieacs-cwmp.service genieacs-nbi.service genieacs-ui.service)
REMOVE_DEPS=false
ASSUME_YES=false

usage() {
  cat <<EOF
Usage: sudo bash uninstall_genieacs.sh [options]

Options:
  --install-dir PATH   GenieACS install directory (default: ${INSTALL_DIR})
  --config-dir PATH    GenieACS config directory (default: ${CONFIG_DIR})
  --log-dir PATH       GenieACS log directory (default: ${LOG_DIR})
  --data-dir PATH      GenieACS data directory (default: ${DATA_DIR})
  --remove-deps        Hapus Redis/MongoDB paket dependensi juga (opsional)
  -y, --yes            Konfirmasi tanpa prompt
  -h, --help           Tampilkan bantuan
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-dir) INSTALL_DIR="$2"; shift 2;;
      --config-dir) CONFIG_DIR="$2"; shift 2;;
      --log-dir) LOG_DIR="$2"; shift 2;;
      --data-dir) DATA_DIR="$2"; shift 2;;
      --remove-deps) REMOVE_DEPS=true; shift 1;;
      -y|--yes) ASSUME_YES=true; shift 1;;
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

confirm() {
  if [[ "$ASSUME_YES" == true ]]; then
    return 0
  fi

  cat <<EOF
Ini akan menghapus semua file GenieACS berikut:
  - ${INSTALL_DIR}
  - ${CONFIG_DIR}
  - ${LOG_DIR}
  - ${DATA_DIR}
  - systemd unit files: ${SYSTEMD_UNITS[*]}
EOF

  if [[ "$REMOVE_DEPS" == true ]]; then
    echo "  - paket Redis dan MongoDB juga akan dihapus"
  fi

  read -rp "Lanjutkan uninstall? [y/N]: " answer
  case "${answer,,}" in
    y|yes) return 0;;
    *) echo "Uninstall dibatalkan."; exit 0;;
  esac
}

stop_services() {
  echo "Menghentikan service GenieACS..."
  for unit in "${SYSTEMD_UNITS[@]}"; do
    if systemctl is-enabled --quiet "$unit" 2>/dev/null || systemctl is-active --quiet "$unit" 2>/dev/null; then
      systemctl stop "$unit" 2>/dev/null || true
      systemctl disable "$unit" 2>/dev/null || true
    fi
  done
  systemctl daemon-reload
}

remove_units() {
  echo "Menghapus service systemd..."
  for unit in "${SYSTEMD_UNITS[@]}"; do
    rm -f "/etc/systemd/system/$unit"
  done
  systemctl daemon-reload
}

remove_paths() {
  echo "Menghapus file dan direktori GenieACS..."
  rm -rf "$INSTALL_DIR"
  rm -rf "$CONFIG_DIR"
  rm -rf "$LOG_DIR"
  rm -rf "$DATA_DIR"
}

remove_user_group() {
  if id -u "$SERVICE_USER" >/dev/null 2>&1; then
    echo "Menghapus user $SERVICE_USER..."
    userdel -r "$SERVICE_USER" 2>/dev/null || userdel "$SERVICE_USER" 2>/dev/null || true
  fi
  if getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
    echo "Menghapus grup $SERVICE_GROUP..."
    groupdel "$SERVICE_GROUP" 2>/dev/null || true
  fi
}

remove_dependencies() {
  if [[ "$REMOVE_DEPS" == false ]]; then
    return
  fi

  echo "Menghapus dependensi Redis dan MongoDB..."
  apt-get purge -y redis-server mongodb-clients mongodb-server || true
  apt-get autoremove -y || true
}

main() {
  parse_args "$@"
  check_root
  confirm
  stop_services
  remove_units
  remove_paths
  remove_user_group
  remove_dependencies

  echo "\nUninstall GenieACS selesai. Semua file GenieACS telah dihapus."
  if [[ "$REMOVE_DEPS" == true ]]; then
    echo "Redis dan MongoDB juga dihapus dari sistem (jika terinstal)."
  fi
}

main "$@"
