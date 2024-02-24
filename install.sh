#!/usr/bin/env bash

# Install packages
apt update
apt install unzip # Required to install Deno
apt install snapd -y
snap install core
snap install --classic certbot
curl -fsSL https://deno.land/install.sh | sh

# Ask for required variables
read -p "The SSH URL of the repository: " repo
read -p "The directory to clone [www]: " dir
read -p "Your email: " email
read -p "The domain: " domain

# Create a SSH key
ssh-keygen -t rsa -b 4096 -C "${email}" -f ~/.ssh/id_rsa

echo "Add the following deploy key to the GitHub repository settings"
echo "and allow write access:"
echo "---"
cat ~/.ssh/id_rsa.pub
echo "---"
read added

# Clone repository
dir="$(pwd)/${dir:-www}"
git clone "${repo}" "${dir}"

# SSL certificate
certbot certonly --agree-tos --standalone -m "${email}" -d "${domain}"

# Create the serve.ts file
cat > ${dir}/serve.ts << EOF
import site from "./_config.ts";
import cms from "./_cms.ts";
import { adapter } from "lume/cms.ts";

site.options.location = new URL("https://${domain}");

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
ExecStart=${HOME}/.deno/bin/deno run -A serve.ts
WorkingDirectory=${dir}
User=root
Restart=always

[Install]
WantedBy=multi-user.target

EOF

# Setup the service
systemctl enable lumecms
systemctl start lumecms
