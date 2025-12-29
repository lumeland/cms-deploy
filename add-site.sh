#!/usr/bin/env bash

# Ask for required variables
read -p "The SSH URL of the repository: " repo
read -p "Your email: " email
read -p "The domain: " domain

dir="$(pwd)/${domain}"

# Create a SSH key
ssh_file="$(pwd)/.ssh/id_rsa_${domain}"
ssh-keygen -t rsa -b 4096 -C "${email}" -N "" -f "${ssh_file}"

echo "Add the following deploy key to the GitHub repository settings"
echo "and allow write access:"
echo "---"
cat "${ssh_file}.pub"
echo "---"
read _

# Setup git repository
git -c core.sshCommand="ssh -i ${ssh_file}" clone "${repo}" "${dir}"

cd "${dir}"
git config user.email "${email}"
git config user.name LumeCMS
git config pull.rebase false
git config core.sshCommand "ssh -i ${ssh_file}"
cd ..

# Create environment variables
cat > "${dir}/.env" << EOF
CMS_USER=admin
CMS_PASSWORD=
EOF

echo "File ${dir}/.env created. Please, edit the environment variables"

# Create Caddyfile
deno="$(pwd)/.deno/bin/deno"
cat >> /etc/caddy/Caddyfile << EOF
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

echo "The site ${domain} has added. Test it at https://${domain}"
echo "Run 'sh add-site.sh' to add additional Lume sites"
