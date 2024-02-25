#!/usr/bin/env bash

# Install packages
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install caddy unzip
curl -fsSL https://deno.land/install.sh | sh

# Ask for required variables
read -p "The SSH URL of the repository: " repo
read -p "Your email: " email
read -p "The domain: " domain
read -p "Username [admin]: " user
read -p "Password: " pass
read -p "Port used for localhost [8000]: " port

port="${port:-8000}"
user="${user:-admin}"
dir="$(pwd)/www_${port}"

# Create a SSH key
ssh-keygen -t rsa -b 4096 -C "${email}" -f ~/.ssh/id_rsa

echo "Add the following deploy key to the GitHub repository settings"
echo "and allow write access:"
echo "---"
cat ~/.ssh/id_rsa.pub
echo "---"
read added

# Setup git repository
git clone "${repo}" "${dir}"
echo "/_serve_lumecms.ts" > ~/.gitignore
git config --global user.email "${email}"
git config --global user.name LumeCMS
git config --global core.excludesfile '~/.gitignore'

# Create the _serve_lumecms.ts file
cat > ${dir}/_serve_lumecms.ts << EOF
import site from "./_config.ts";
import cms from "./_cms.ts";
import { adapter } from "lume/cms.ts";

site.options.location = new URL("https://${domain}");
cms.options.auth = { method: "basic", users: { ${user}: "${pass}" }};

const app = await adapter({ site, cms });

Deno.serve({
  port: ${port},
  handler: app.fetch,
});

EOF

# Create the Deno service
cat > "/etc/systemd/system/lumecms_${port}.service" << EOF
[Unit]
Description=LumeCMS
Documentation=http://lume.land
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${HOME}/.deno/bin/deno run -A _serve_lumecms.ts
WorkingDirectory=${dir}
User=root
Restart=always

[Install]
WantedBy=multi-user.target

EOF

# Setup the service
systemctl enable "lumecms_${port}.service"
systemctl start "lumecms_${port}.service"

# Create Caddyfile
cat > /etc/caddy/Caddyfile << EOF
${domain} {
  reverse_proxy :${port}
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
