#!/usr/bin/env sh

# Install and update packages
sudo apt update -y
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl git unzip

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
sudo mv ./caddy /usr/bin/caddy

# Setup Caddy service
sudo mkdir -p /etc/caddy
sudo touch /etc/caddy/Caddyfile
sudo tee /etc/systemd/system/caddy.service > /dev/null << EOF
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
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

sudo systemctl enable ufw

# Add site
curl https://lumeland.github.io/cms-deploy/add-site.sh > add-site.sh
read -p "Would you like to add a site? (Y/n): " add_site
add_site=${add_site:-Y}
if [ "$add_site" = "y" || "$add_site" = "Y" ]; then
  sh add-site.sh
else
  echo "No site added"
  echo "Run 'sh add-site.sh' to add Lume sites to this server"
fi
