#!/usr/bin/env bash

# Install and update packages
apt update -y
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl git unzip

# Install Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list
apt update -y
apt install -y caddy

# Install custom Caddy with Lume
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

# Configure official Caddy and custom Caddy-Lume
dpkg-divert --divert /usr/bin/caddy.default --rename /usr/bin/caddy
mv ./caddy /usr/bin/caddy.custom
update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.default 10
update-alternatives --install /usr/bin/caddy caddy /usr/bin/caddy.custom 50
systemctl restart caddy

# Install Deno
curl -fsSL https://deno.land/install.sh > deno.sh
sh deno.sh -y
rm deno.sh
source ~/.bashrc
deno="$(which deno)"

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

# Create Caddyfile
mkdir -p /etc/caddy
cat > /etc/caddy/Caddyfile << EOF
${domain} {
  reverse_proxy {
		dynamic lume {
			directory "${dir}"
			deno "${deno}"
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
