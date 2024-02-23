#!/usr/bin/env bash

deno_exec="${HOME}/.deno/bin/deno"

# Install Deno
curl -fsSL https://deno.land/install.sh | sh

# Clone repository
read -p "SSH URL of the repository to clone: " repo
read -p "Folder target: " folder

dir="$(pwd)/${folder}"
git clone "${repo}" "${dir}"

# Install SSL certificate
apt update
apt install snapd -y
snap install core
snap install --classic certbot

read -p "Your email for important notifications: " email
read -p "Which domain do you want to use? " domain

certbot certonly --agree-tos --standalone -m "${email}" -d "${domain}"

# Create the server.ts file
cat > ${dir}/server.ts << EOF
import site from "./_config.ts";
import cms from "./_cms.ts";
import { adapter } from "lume/cms.ts";

const app = await adapter({ site, cms });

Deno.serve({
  port: 443,
  handler: app.fetch,
  cert: Deno.readTextFileSync("/etc/letsencrypt/live/${domain}/fullchain.pem"),
  key: Deno.readTextFileSync("/etc/letsencrypt/live/${domain}/privkey.pem"),
});

EOF

# Create the Deno service
cat > /etc/systemd/system/lumecms.service << EOF
[Unit]
Description=LumeCMS
Documentation=http://lume.land
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${deno_exec} run -A admin.ts
WorkingDirectory=${dir}
User=root
Restart=always

[Install]
WantedBy=multi-user.target

EOF

# Setup the service
systemctl enable lumecms
systemctl start lumecms
