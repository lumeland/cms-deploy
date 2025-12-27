#!/usr/bin/env bash

# Update packages
apt update -y
apt install -y git unzip

# Install Deno
curl -fsSL https://deno.land/install.sh | sh

# Install custom Caddy with Lume
if [ $(uname -sm) = "Linux aarch64" ]; then
  target="linux-amd64"
else
  target="linux-arm64"
fi
binary_url="https://github.com/lumeland/caddy-lume/releases/latest/download/caddy-lume-${target}"
binary_path="/usr/bin/caddy"
curl --fail --location --progress-bar --output "$binary_path" "$binary_url"

# Ask for required variables
read -p "The SSH URL of the repository: " repo
read -p "Your email: " email
read -p "The domain: " domain

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

# Create environment variables
cat > "${dir}/.env" << EOF
CMS_USER=admin
CMS_PASSWORD=
EOF

echo "File ${dir}/.env created. Please, edit the environment variables"

# Setup Caddy service
groupadd --system caddy
useradd --system \
  --gid caddy \
  --create-home \
  --home-dir /var/lib/caddy \
  --shell /usr/sbin/nologin \
  --comment "Caddy+Lume web server" \
  caddy

cat > /etc/systemd/system/caddy.service << EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
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

# Create Caddyfile
cat > /etc/caddy/Caddyfile << EOF
${domain} {
  reverse_proxy {
		dynamic lume {
			directory "${dir}"
		}

		lb_retries 10
		lb_try_interval 2s
	}
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
