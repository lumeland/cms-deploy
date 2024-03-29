# How to deploy LumeCMS in a VPS

1. Get a VPS from [Hetzner](https://www.hetzner.com/),
   [Digital Ocean](https://www.digitalocean.com/), etc.
   - This script was tested only on Ubuntu 20.04.
2. Create an `A` record in the DNS settings of your domain to the server IP. For
   example, `cms.example.com`.
3. Log in from SSH and run:
   ```sh
   curl https://raw.githubusercontent.com/lumeland/cms-deploy/main/install-caddy.sh > install.sh && sh install.sh
   ```
4. After updating and installing some packages, the script will ask you for some
   info:
   - The **URL of the repository**. Example: `git@github.com:user/repo.git`.
   - An **email**. It's used for git commits, or to create the SSL certificate.
   - The **domain** for the CMS: `cms.example.com`.
   - An **username**. It's used to login in the CMS. By default is `admin`.
   - A **password**. Used for the login.
   - On generating the public/private rsa key pair, leave the passphrase empty.
   - During the process, it will ask you to add a deploy key.
     - Go to the GitHub respository / Settings / Deploy keys / Add deploy key.
     - Paste the key printed in the terminal.
     - Make sure to check "Allow write access".
     - Once the key is added, press Enter in the terminal to continue.

5. When the script is finished, wait a few seconds before openiing the domain in
   your browser. You should see your site and be able to edit the pages.
