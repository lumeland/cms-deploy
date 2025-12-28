# Deploy LumeCMS in a VPS

## Requirements

- A VPS from [Hetzner](https://www.hetzner.com/),
  [Digital Ocean](https://www.digitalocean.com/), or similar service with Ubuntu
  24.04
- A domain pointing to the server, like `cms.example.com`.

## LumeCMS configuration

Enable the authentication and GIT in the `_cms.ts` file:

```js
// user and pass are environment variables, stored in an .env file
const user = Deno.env.get("CMS_USER") ?? "admin";
const pass = Deno.env.get("CMS_PASSWORD") ?? "";

cms.auth({
  [user]: pass,
});

// Enable git to pull/push changes
cms.git();
```

## Instructions

1. Log in from SSH and run:
   ```sh
   curl https://lumeland.github.io/cms-deploy/install.sh > install.sh && sh install.sh
   ```
2. After updating and installing some packages, the script will ask you for some
   info:
   - The **SSH URL of the repository**. Example: `git@github.com:user/repo.git`.
   - An **email**. It's used for git commits, or to create the SSL certificate.
   - The **domain** for the CMS: `cms.example.com`.
   - During the process, it will ask you to add a deploy key.
     - Go to the GitHub respository / Settings / Deploy keys / Add deploy key.
     - Paste the key printed in the terminal.
     - Check "Allow write access".
     - Once the key is added, press Enter in the terminal to continue.

3. Done! When the script is finished you should see your site and be able to
   edit the pages.
