# How to deploy LumeCMS in a VPS

1. In your deno.json file create the following task:
   ```json
   {
     "tasks": {
       "cms:prod": "deno serve -A --env-file https://deno.land/x/lume_cms_adapter@v0.2.2/mod.ts"
     }
   }
   ```
2. Get a VPS from [Hetzner](https://www.hetzner.com/),
   [Digital Ocean](https://www.digitalocean.com/), or similar service.
   - This script was tested only on Ubuntu 24.04.
3. Create an `A` record in the DNS settings of your domain to the server IP. For
   example, `cms.example.com`.
4. Log in from SSH and run:
   ```sh
   curl https://lumeland.github.io/cms-deploy/install.sh > install.sh && sh install.sh
   ```
5. After updating and installing some packages, the script will ask you for some
   info:
   - The **SSH URL of the repository**. Example: `git@github.com:user/repo.git`.
   - An **email**. It's used for git commits, or to create the SSL certificate.
   - The **domain** for the CMS: `cms.example.com`.
   - When generating the public/private rsa key pair, leave the passphrase
     empty.
   - During the process, it will ask you to add a deploy key.
     - Go to the GitHub respository / Settings / Deploy keys / Add deploy key.
     - Paste the key printed in the terminal.
     - Make sure to check "Allow write access".
     - Once the key is added, press Enter in the terminal to continue.

6. When the script is finished you should see your site and be able to edit the
   pages.
