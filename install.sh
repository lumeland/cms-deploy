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
read -p "Username [admin]: " user
read -p "Password: " pass

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

cat > ~/.gitignore << EOF
_cms.lume.ts
_cms.serve.ts
EOF

git config --global user.email "${email}"
git config --global user.name LumeCMS
git config --global core.excludesfile '~/.gitignore'

# Create the _cms.lume.ts file to merge Lume and LumeCMS
cat > ${dir}/_cms.lume.ts << EOF
import site from "./_config.ts";
import cms from "./_cms.ts";
import adapter from "lume/cms/adapters/lume.ts";

cms.options.auth = undefined;
site.options.location = new URL("https://${domain}");

export default await adapter({ site, cms });
EOF

# Create the _cms.serve.ts file to serve LumeCMS
cat > ${dir}/_cms.serve.ts << EOF
import serve from "lume/cms/server/proxy.ts";

export default serve({
  serve: "_cms.lume.ts",
  git: true,
  auth: {
    method: "basic",
    users: {
      "${user}": "${pass}"
    }
  },
  env: {
    LUME_LOGS: "error",
  }
});
EOF

# Create the Deno service
cat > "/etc/systemd/system/lumecms.service" << EOF
[Unit]
Description=LumeCMS
Documentation=http://lume.land
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${HOME}/.deno/bin/deno serve -A _cms.serve.ts
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

# Restart the process if the CPU usage is above 95%
# https://github.com/denoland/deno/issues/23033
script_path="$(pwd)/cron_cpu.sh"

cat > ${script_path} << EOF
#!/usr/bin/env bash

CPU_USAGE_THRESHOLD=99
CPU_USAGE=\$(top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{printf "%.0f", 100 - \$1}')

if [ "\$CPU_USAGE" -gt "\$CPU_USAGE_THRESHOLD" ]; then
  systemctl restart lumecms
  systemctl restart caddy
fi
EOF

chmod +x "${script_path}"

# Setup the cron job to run the script
crontab -l > /tmp/mycron
echo "*/5 * * * * ${script_path}" >> /tmp/mycron
crontab /tmp/mycron
rm /tmp/mycron
