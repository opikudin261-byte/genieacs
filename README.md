# Instalasi GenieACS

Skrip ini menyediakan instalasi GenieACS lengkap dengan parameter penuh dan dukungan untuk banyak jenis ONU/TR-069 CPE. Tujuannya adalah konfigurasi yang ringan dan mudah disesuaikan.

## Persyaratan

- Debian/Ubuntu (tested)
- Akses root atau sudo
- MongoDB
- Redis
- Node.js 18.x

## Cara menggunakan

1. Jalankan skrip sebagai root:

```bash
sudo bash install_genieacs.sh
```

2. Atau bisa ubah parameter:

```bash
sudo bash install_genieacs.sh \
  --version 2.11.0 \
  --install-dir /opt/genieacs \
  --web-port 3000 \
  --api-port 7557 \
  --cwmp-port 7547 \
  --bind-address 0.0.0.0 \
  --mongo-host 127.0.0.1 \
  --redis-host 127.0.0.1
```

3. Letakkan `logo.png` di direktori yang sama dengan `install_genieacs.sh` atau gunakan `--logo-path` untuk custom path.

```bash
sudo bash install_genieacs.sh --logo-path /path/to/logo.png
```

## File utama

- `install_genieacs.sh`: skrip instalasi utama
- `/etc/genieacs/production.env`: variabel lingkungan GenieACS
- `/etc/genieacs/production.json`: konfigurasi dasar GenieACS
- `/etc/systemd/system/genieacs-cwmp.service`: service CWMP
- `/etc/systemd/system/genieacs-nbi.service`: service NBI
- `/etc/systemd/system/genieacs-ui.service`: service UI

## Dukungan ONU

Skrip ini menyiapkan GenieACS dengan konfigurasi dasar yang memungkinkan:

- Auto provisioning dan auto sync
- Profil perangkat default
- Penyimpanan data MongoDB dan Redis
- Support banyak model ONU/TR-069 melalui template dan profile di GenieACS

Untuk mendukung berbagai macam ONU, tambahkan template device dan provisioning profile di GenieACS UI atau via API.

## Tips ringan dan maksimal

- Jalankan MongoDB dan Redis di mesin yang sama untuk performa bila beban ringan
- Gunakan Nginx atau Traefik sebagai reverse proxy untuk TLS dan load balancing jika diperlukan
- Pastikan hanya service GenieACS yang dibutuhkan diaktifkan
- Jika CPU terbatas, gunakan mode `production` dan atur `LOG_LEVEL=warn`

## Uninstall GenieACS

Untuk menghapus GenieACS bersih, gunakan skrip:

```bash
sudo bash uninstall_genieacs.sh
```

Opsi tambahan:

- `-y` atau `--yes` untuk melewati konfirmasi
- `--install-dir` untuk path instalasi GenieACS jika berbeda dari `/opt/genieacs`
- `--config-dir` untuk path config jika berbeda dari `/etc/genieacs`
- `--log-dir` untuk path log jika berbeda dari `/var/log/genieacs`
- `--data-dir` untuk path data jika berbeda dari `/var/lib/genieacs`
- `--remove-deps` untuk menghapus paket Redis dan MongoDB juga (opsional)

Contoh:

```bash
sudo bash uninstall_genieacs.sh --yes --remove-deps
```

## Customisasi lanjutan

Skrip siap dikustom untuk:

- `GENIEACS_VERSION` untuk update versi
- `CWMP`, `NBI`, dan `UI` ports
- `MONGO` dan `REDIS` host/port
- `BIND_ADDRESS` untuk network interface tertentu

---

Untuk dukungan lebih lanjut, tambahkan profil ONU spesifik di GenieACS dan gunakan `device template` untuk vendor Huawei, ZTE, MikroTik, Nokia, GPON CPE, dan model lain yang umum dipasaran.
