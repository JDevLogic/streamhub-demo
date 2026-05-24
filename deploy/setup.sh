#!/bin/bash
# Run this once on the VPS as root

set -e

APP_DIR=/root/streamhub

# 1. System deps
apt update && apt install -y python3 python3-pip python3-venv nginx

# 2. Virtualenv + packages
cd $APP_DIR/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Systemd service
cp $APP_DIR/deploy/streamhub.service /etc/systemd/system/streamhub.service
systemctl daemon-reload
systemctl enable streamhub
systemctl start streamhub

# 4. Nginx
cp $APP_DIR/deploy/nginx.conf /etc/nginx/sites-available/streamhub
ln -sf /etc/nginx/sites-available/streamhub /etc/nginx/sites-enabled/streamhub
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# 5. Firewall
ufw allow OpenSSH
ufw allow 80
ufw --force enable

echo "✓ StreamHub desplegado en http://YOUR_VPS_IP"
