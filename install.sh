#!/usr/bin/env bash

# Install packages
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update -y
apt install -y git unzip caddy
curl -fsSL https://deno.land/install.sh | sh

# Ask for required variables
read -p "The SSH URL of the repository: " repo
read -p "Your email: " email
read -p "The domain: " domain

user="${user:-admin}"
dir="$(pwd)/www"

# Create a SSH key
ssh-keygen -t rsa -b 4096 -C "${email}" -N "" -f ~/.ssh/id_rsa

echo "Add the following deploy key to the GitHub repository settings"
echo "and allow write access:"
echo "---"
cat ~/.ssh/id_rsa.pub
echo "---"
read added

# Setup git repository
git clone "${repo}" "${dir}"

git config --global user.email "${email}"
git config --global user.name LumeCMS
git config --global pull.rebase false

# Create the Deno service
cat > "/etc/systemd/system/lumecms.service" << EOF
[Unit]
Description=LumeCMS
Documentation=http://lume.land
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${HOME}/.deno/bin/deno task cms:prod -- --location=https://${domain}
WorkingDirectory=${dir}
User=root
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target

EOF

# Setup the service
systemctl enable "lumecms.service"
systemctl start "lumecms.service"

# Create Caddyfile
cat > /etc/caddy/Caddyfile << EOF
${domain} {
  reverse_proxy :8000
}
EOF

caddy fmt /etc/caddy/Caddyfile --overwrite
systemctl restart caddy
systemctl enable caddy

# Setup firewall
ufw allow ssh
ufw allow 80
ufw allow 443
ufw enable

systemctl enable ufw
