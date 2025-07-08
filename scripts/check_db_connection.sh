#!/bin/bash

# Script untuk memeriksa koneksi ke database PostgreSQL eksternal

echo "Memeriksa koneksi ke PostgreSQL eksternal..."

# Hardcoded values untuk testing
DB_HOST="10.0.29.40"
DB_PORT="5432"
DB_NAME="mkt_ryo"
DB_USER="jagoan2025"
DB_PASSWORD="Jag0db@2025"

# Jika ada file .env, coba baca nilai-nilai spesifik
if [ -f .env ]; then
  echo "Membaca konfigurasi dari file .env..."
  
  # Baca nilai-nilai spesifik dari file .env dengan grep dan pastikan tidak ada whitespace atau karakter aneh
  PSQL_HOST=$(grep -E "^PSQL_HOST=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d " " | tr -d "\r")
  PSQL_PORT=$(grep -E "^PSQL_PORT=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d " " | tr -d "\r")
  PSQL_NAME=$(grep -E "^PSQL_NAME=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d " " | tr -d "\r")
  PSQL_USER=$(grep -E "^PSQL_USER=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d " " | tr -d "\r")
  PSQL_PASSWORD=$(grep -E "^PSQL_PASSWORD=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d " " | tr -d "\r")
  
  # Debug output untuk memeriksa nilai yang dibaca
  echo "Debug - Variabel dari .env (dalam format |nilai|):"
  echo "| PSQL_HOST: |${PSQL_HOST}|"
  echo "| PSQL_PORT: |${PSQL_PORT}|"
  
  # Gunakan nilai-nilai dari file jika ada dan tidak kosong
  [ -n "$PSQL_HOST" ] && DB_HOST="$PSQL_HOST"
  [ -n "$PSQL_PORT" ] && DB_PORT="$PSQL_PORT"
  [ -n "$PSQL_NAME" ] && DB_NAME="$PSQL_NAME" 
  [ -n "$PSQL_USER" ] && DB_USER="$PSQL_USER"
  [ -n "$PSQL_PASSWORD" ] && DB_PASSWORD="$PSQL_PASSWORD"
fi

echo "Memeriksa koneksi ke $DB_HOST:$DB_PORT..."
echo "Database name: $DB_NAME"
echo "Database user: $DB_USER"
echo "--------------------------------------------------------"

# Pastikan DB_HOST bersih
clean_host=$(echo "$DB_HOST" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")
echo "HOST yang digunakan (setelah dibersihkan): |${clean_host}|"

# Verifikasi IP address (pastikan ini bukan host name)
echo "Verifikasi format IP address: |${clean_host}|"
if [[ "${clean_host}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Format IP address valid."
else
  echo "PERINGATAN: |${clean_host}| tidak terlihat seperti IP address valid. Pastikan format benar."
fi

# Cek routing untuk IP address
echo "Memeriksa routing ke host..."
ip route get "${clean_host}" 2>&1 || echo "Tidak dapat menemukan rute ke host"

# Cek apakah command ping tersedia
if command -v ping &> /dev/null; then
  echo "Memeriksa network reachability ke database host..."
  # Pastikan DB_HOST bersih sebelum ping
  clean_host=$(echo "$DB_HOST" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")
  echo "Mencoba ping ke: |${clean_host}|"
  ping -c 1 -W 2 "${clean_host}" || echo "Host tidak dapat di-ping, tapi koneksi database masih mungkin berfungsi"
else
  echo "Command ping tidak tersedia. Melanjutkan..."
fi

# Pastikan DB_HOST dan DB_PORT bersih sebelum digunakan lebih lanjut
clean_host=$(echo "$DB_HOST" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")
clean_port=$(echo "$DB_PORT" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")

# Cek apakah telnet tersedia (alternatif untuk nc)
if command -v telnet &> /dev/null; then
  echo "Mencoba koneksi telnet ke PostgreSQL port..."
  echo "Telnet ke |${clean_host}:${clean_port}|"
  timeout 5 telnet "${clean_host}" "${clean_port}" </dev/null 2>&1 | grep -i connected || echo "Telnet tidak dapat terhubung ke port PostgreSQL"
fi

# Cek apakah netcat tersedia dan port PostgreSQL terbuka
if command -v nc &> /dev/null; then
  echo "Memeriksa apakah port PostgreSQL terbuka..."
  echo "Netcat ke |${clean_host}:${clean_port}|"
  if nc -zv -w 5 "${clean_host}" "${clean_port}" 2>&1; then
    echo "Port PostgreSQL terbuka."
  else
    echo "PERINGATAN: Port PostgreSQL tidak dapat diakses! Coba koneksi langsung..."
  fi
else
  echo "Command nc tidak tersedia. Melanjutkan..."
fi

# Mencoba DNS lookup untuk host
echo "Mencoba DNS lookup untuk host |${clean_host}|..."
if command -v nslookup &> /dev/null; then
  nslookup "${clean_host}" || echo "DNS lookup gagal"
elif command -v host &> /dev/null; then
  host "${clean_host}" || echo "DNS lookup gagal"
fi

# Cek apakah psql tersedia
if command -v psql &> /dev/null; then
  echo "Memeriksa koneksi database menggunakan psql..."
  # Pastikan semua parameter bersih sebelum koneksi
  clean_host=$(echo "$DB_HOST" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")
  clean_port=$(echo "$DB_PORT" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")
  clean_user=$(echo "$DB_USER" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")
  clean_name=$(echo "$DB_NAME" | tr -d '\r\n\t ' | tr -d '"' | tr -d "'")
  
  echo "Mencoba koneksi: psql -h |${clean_host}| -p |${clean_port}| -U |${clean_user}| -d |${clean_name}|"
  
  # Simpan output koneksi untuk debugging
  export PGCONNECT_TIMEOUT=10
  export PGPASSWORD="$DB_PASSWORD"
  psql -h "${clean_host}" -p "${clean_port}" -U "${clean_user}" -d "${clean_name}" -c "\conninfo" -w
  PSQL_RESULT=$?
  
  if [ $PSQL_RESULT -eq 0 ]; then
    echo "✅ Koneksi ke database berhasil!"
    CONNECTION_SUCCESSFUL=true
  else
    echo "❌ Gagal terhubung ke database dengan psql! (error code: $PSQL_RESULT)"
    CONNECTION_SUCCESSFUL=false
    echo "Mencoba lagi dengan parameter tambahan untuk debugging..."
    
    # Capture error message untuk diagnosa
    ERROR_OUTPUT=$(PGCONNECT_TIMEOUT=10 PGPASSWORD="$DB_PASSWORD" psql -v ON_ERROR_STOP=1 -h "${clean_host}" -p "${clean_port}" -U "${clean_user}" -d "${clean_name}" -c "SELECT 1" 2>&1)
    echo "$ERROR_OUTPUT"
    
    # Analisa pesan error umum
    if echo "$ERROR_OUTPUT" | grep -q "could not translate host"; then
      echo "⚠️ ERROR ANALYSIS: Gagal menerjemahkan hostname. Pastikan DNS berfungsi atau gunakan IP address langsung."
    elif echo "$ERROR_OUTPUT" | grep -q "connection refused"; then
      echo "⚠️ ERROR ANALYSIS: Koneksi ditolak. PostgreSQL mungkin tidak berjalan atau firewall memblokir."
    elif echo "$ERROR_OUTPUT" | grep -q "timeout expired"; then
      echo "⚠️ ERROR ANALYSIS: Koneksi timeout. Server mungkin offline atau firewall memblokir."
    elif echo "$ERROR_OUTPUT" | grep -q "password authentication failed"; then
      echo "⚠️ ERROR ANALYSIS: Autentikasi gagal. Username/password salah."
    elif echo "$ERROR_OUTPUT" | grep -q "database.*does not exist"; then
      echo "⚠️ ERROR ANALYSIS: Database tidak ditemukan. Periksa nama database."
    elif echo "$ERROR_OUTPUT" | grep -q "no route to host"; then
      echo "⚠️ ERROR ANALYSIS: Tidak ada rute ke host. Masalah routing jaringan."
    elif echo "$ERROR_OUTPUT" | grep -q "name or service not known"; then
      echo "⚠️ ERROR ANALYSIS: Hostname tidak dikenal. Pastikan hostname valid atau gunakan IP."
    fi
  fi
else
  echo "Command psql tidak tersedia. Pastikan postgresql-client terinstal."
fi

# Simpan informasi tambahan
echo "--------------------------------------------------------"
echo "Pemeriksaan koneksi selesai."
echo ""
echo "INFORMASI TAMBAHAN"
echo "--------------------------------------------------------"
echo "OS: $(uname -a)"
echo "PostgreSQL client: $(command -v psql && psql --version || echo "Tidak terinstal")"
echo "Network tools: $(command -v nc && nc -h 2>&1 | head -n1 || echo "netcat tidak terinstal")"
echo "Hostname: $(hostname)"
echo "IP Addresses: $(ip addr show | grep -w inet | awk '{print $2}')"
echo "Default gateway: $(ip route | grep default)"
echo "--------------------------------------------------------"
echo "Untuk menginstal tools yang diperlukan pada Ubuntu/Debian:"
echo "  sudo apt update && sudo apt install -y postgresql-client netcat-openbsd dnsutils iproute2"
echo ""
echo "CATATAN PENTING:"
echo "Jika server PostgreSQL berada di VPC/jaringan terpisah, pastikan:"
echo "1. Security group/Firewall mengizinkan akses dari IP ini ke port PostgreSQL (5432)"
echo "2. Routing antar jaringan dikonfigurasi dengan benar"
echo "3. PostgreSQL server dikonfigurasi untuk menerima koneksi dari IP ini di pg_hba.conf"
echo ""
echo "--------------------------------------------------------"
echo "RINGKASAN HASIL PEMERIKSAAN"
echo "--------------------------------------------------------"
echo "Host Database  : ${clean_host}"
echo "Port           : ${clean_port}"
echo "Database Name  : ${clean_name}"
echo "Database User  : ${clean_user}"

if [ "$CONNECTION_SUCCESSFUL" = true ]; then
  echo "Status Koneksi: ✅ BERHASIL"
  echo "--------------------------------------------------------"
  echo "Database sudah bisa diakses dengan baik!"
  exit 0
else
  echo "Status Koneksi: ❌ GAGAL"
  echo "--------------------------------------------------------"
  echo "Langkah troubleshooting:"
  echo "1. Periksa apakah PostgreSQL berjalan di ${clean_host}:${clean_port}"
  echo "2. Pastikan firewall server mengizinkan koneksi dari IP ini"
  echo "3. Cek file pg_hba.conf di server PostgreSQL untuk allow connections"
  echo "4. Verifikasi kredensial login (username/password)"
  echo "5. Coba gunakan docker_check_db.sh untuk tes dari container Docker"
  echo "--------------------------------------------------------"
  exit 1
fi
echo "--------------------------------------------------------"
