#!/usr/bin/env bash

# Install and update packages
apt update -y
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl git unzip

# Install Caddy with Lume
if [ $(uname -m) = "x86_64" ]; then
  target="linux-amd64"
else
  target="linux-arm64"
fi
binary_url="https://github.com/lumeland/caddy-lume/releases/latest/download/caddy-lume-${target}.tar.gz"
curl --fail --location --progress-bar --output caddy.tar.gz "$binary_url"
tar -xf caddy.tar.gz
mv "bin/caddy-lume-$target" ./caddy
chmod +x caddy
rm caddy.tar.gz
rm -rf bin
mv ./caddy /usr/bin/caddy

# Setup Caddy service
mkdir -p /etc/caddy
touch /etc/caddy/Caddyfile
cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# Install Deno
curl -fsSL https://deno.land/install.sh > deno.sh
deno="$(pwd)/.deno"
DENO_INSTALL="${deno}" sh deno.sh -y --no-modify-path
rm deno.sh

# Setup firewall
ufw allow ssh
ufw allow 80
ufw allow 443
ufw --force enable

systemctl enable ufw

# Add site
curl https://lumeland.github.io/cms-deploy/add-site.sh > add-site.sh
read -p "Would you like to add a site? (Y/n): " add_site
add_site=${add_site:-Y}
if [[ "$add_site" == "y" || "$add_site" == "Y" ]]; then
  sh add-site.sh
fi
