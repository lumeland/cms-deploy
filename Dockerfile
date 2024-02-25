FROM denoland/deno:latest

WORKDIR /app

RUN apt update && apt install -y ca-certificates git openssh-client

CMD [ "run", "-A", "serve.ts" ]
