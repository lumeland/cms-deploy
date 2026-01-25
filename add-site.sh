#!/usr/bin/env sh

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
read -p "Create an .env file? (Y/n): " response
response=${response:-Y}

if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
read -p "CMS_USER=" user
read -p "CMS_PASSWORD=" password

cat > "${dir}/.env" << EOF
CMS_USER=${user}
CMS_PASSWORD=${password}
EOF

echo "File ${dir}/.env created."
fi

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

# Configure the production site
read -p "Would you like to serve the production site? (y/N): " prod_site
prod_site=${prod_site:-N}

if [ "$prod_site" = "y" ] || [ "$prod_site" = "Y" ]; then
  read -p "Domain of the production site: " prod_domain
  read -p "Production branch (main): " prod_branch
	prod_dir="$(pwd)/${prod_domain}"
	prod_branch=${prod_branch:-main}

	mkdir "$prod_dir"

	# Git hook to build the site on push the production branch
	cat > "${dir}/.git/hooks/pre-push" << EOF
#!/bin/sh

remote="$1"
url="$2"
prod_branch="refs/heads/${prod_branch}"

while read local_ref local_sha remote_ref remote_sha
do
	if [ "\$local_ref" = \$prod_branch ]
	then
		${deno} task build --location=https://${prod_domain} --dest=_prod
		mv ${prod_dir}/www ${prod_dir}/www_old
		mv _prod ${prod_dir}/www
		rm -rf ${prod_dir}/www_old
	fi
done

exit 0
EOF
	chmod +x "${dir}/.git/hooks/pre-push"

	# Configure Caddy to serve the site
	cat >> /etc/caddy/Caddyfile << EOF
${prod_domain} {
	root * ${prod_dir}/www
	encode
  file_server
	log {
		output file ${prod_dir}/access.log
	}
}
EOF
fi

# Restart services
caddy fmt /etc/caddy/Caddyfile --overwrite
systemctl restart caddy
systemctl enable caddy

echo "The site ${domain} has added. Test it at https://${domain}"
echo "Run 'sh add-site.sh' to add additional Lume sites"
