FROM denoland/deno:latest

# Set the working directory
WORKDIR /app

# Expose port 8000
EXPOSE 8000

# Deno cache directory
ENV DENO_DIR /_deno

RUN apt update && apt install -y git

CMD [ "serve", "-A", "https://deno.land/x/lume_cms_adapter@v0.1.3/mod.ts", "--", "--location", "http://localhost:8000" ]
