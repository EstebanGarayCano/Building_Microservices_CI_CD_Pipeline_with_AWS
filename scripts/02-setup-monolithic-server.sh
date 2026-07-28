#!/bin/bash
# =============================================================================
# Script: 02-setup-monolithic-server.sh
# Phase 2 - Recovery script for MonolithicAppServer.
# Run this on the MonolithicAppServer EC2 instance via EC2 Instance Connect
# if the Node.js app is not running (e.g., after a reboot or failed cloud-init).
#
# Usage: bash 02-setup-monolithic-server.sh
# =============================================================================

set -e

# ---- CONFIGURATION (update if RDS endpoint changes) ----
DB_HOST="supplierdb.ccvabjcg6ue0.us-east-1.rds.amazonaws.com"
DB_USER="nodeapp"
DB_PASS="coffee"
DB_NAME="COFFEE"
APP_DIR="/home/ubuntu/resources/codebase_partner"
CODE_ZIP_URL="https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACCDEV-2-91558/04-lab-microservices/code.zip"
# --------------------------------------------------------

echo "======================================================"
echo " Phase 2 - MonolithicAppServer Recovery Setup"
echo "======================================================"

# Check if app is already running
if pgrep -f "node index.js" > /dev/null; then
  echo "[+] Node.js app is already running. Nothing to do."
  exit 0
fi

# 1. Install nvm if not present
if ! command -v nvm &> /dev/null && [ ! -d "$HOME/.nvm" ]; then
  echo "[*] Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  echo "[+] nvm already installed."
fi

# 2. Install Node.js 14 if not present
if ! node --version &> /dev/null; then
  echo "[*] Installing Node.js 14..."
  nvm install 14
  nvm use 14
else
  echo "[+] Node.js already installed: $(node --version)"
fi

# 3. Download and extract code if not present
if [ ! -d "$APP_DIR" ]; then
  echo "[*] Downloading application code..."
  sudo apt-get install -y unzip --fix-missing 2>/dev/null || true
  wget -O /home/ubuntu/code.zip "$CODE_ZIP_URL"
  cd /home/ubuntu
  unzip -o code.zip
  echo "[+] Code extracted to $APP_DIR"
fi

# 4. Install npm dependencies
if [ ! -d "$APP_DIR/node_modules" ]; then
  echo "[*] Installing npm dependencies..."
  cd "$APP_DIR"
  npm install
fi

# 5. Set up RDS database (idempotent)
if command -v mysql &> /dev/null; then
  echo "[*] Setting up RDS database..."
  mysql -h "$DB_HOST" -u admin -p <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
USE $DB_NAME;
CREATE TABLE IF NOT EXISTS suppliers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  address VARCHAR(255),
  city VARCHAR(255),
  state VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(255)
);
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
  echo "[+] Database setup complete."
else
  echo "[~] mysql client not found. Skipping DB setup (DB may already be configured)."
fi

# 6. Start the application
echo "[*] Starting Node.js application on port 80..."
cd "$APP_DIR"
sudo -E $(which node) index.js &
sleep 2

if pgrep -f "node index.js" > /dev/null; then
  echo "[+] Application started successfully."
  echo "[+] Access at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo '<public-ip>')"
else
  echo "[-] ERROR: Application failed to start. Check the logs."
  exit 1
fi

echo "======================================================"
