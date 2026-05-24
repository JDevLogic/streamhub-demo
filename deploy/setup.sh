#!/bin/bash
# Run this once on the VPS as root

set -e

APP_DIR=/opt/streamhub

# 1. System deps
apt update && apt install -y python3 python3-pip python3-venv nginx

# 2. Usuario de sistema sin privilegios
useradd --system --no-create-home --shell /usr/sbin/nologin streamhub || true
chown -R streamhub:streamhub $APP_DIR

# 3. Virtualenv + packages
cd $APP_DIR/backend
python3 -m venv venv
chown -R streamhub:streamhub $APP_DIR/backend/venv
pip install -r requirements.txt

# 4. Systemd service
cp $APP_DIR/deploy/streamhub.service /etc/systemd/system/streamhub.service
systemctl daemon-reload
systemctl enable streamhub
systemctl start streamhub

# 5. Nginx
cp $APP_DIR/deploy/nginx.conf /etc/nginx/sites-available/streamhub
ln -sf /etc/nginx/sites-available/streamhub /etc/nginx/sites-enabled/streamhub
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# 6. Firewall
ufw allow OpenSSH
ufw allow 80
ufw --force enable

echo "✓ StreamHub desplegado."
echo ""
echo "Pasos siguientes:"
echo "  1. Copia y edita el fichero de entorno:  cp $APP_DIR/backend/.env.example $APP_DIR/backend/.env"
echo "  2. Reinicia el servicio tras configurar:  systemctl restart streamhub"
echo "  3. Comprueba el estado:                   systemctl status streamhub"
