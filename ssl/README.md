# SSL Certificate

The instructions below will help you deploy a signed SSL certificate for your Satisfactory server. Without one,
Satisfactory falls back to a self-signed cert, requiring players to manually confirm it when they first connect.

The game always expects the cert at two fixed paths inside the container, regardless of where it came from:

- `/config/gamefiles/FactoryGame/Certificates/cert_chain.pem`
- `/config/gamefiles/FactoryGame/Certificates/private_key.pem`

**Your cert must not be a wildcard, and must include the exact hostname players connect to as a SAN.**
Satisfactory doesn't support wildcard certs or SNI-less matching ([#354](https://github.com/wolveix/satisfactory-server/issues/354)).
See [Troubleshooting](#troubleshooting) below for more on this.

Pick the setup that matches you:

- [Standalone (Certbot)](#standalone-certbot) — you don't have a reverse proxy already issuing certs.
- [Reusing an Existing Reverse Proxy's Cert](#reusing-an-existing-reverse-proxys-cert) — you already run
  Nginx Proxy Manager, Traefik, Caddy, etc. and it's already managing a Let's Encrypt cert for you.

## Standalone (Certbot)

```yaml
services:
  satisfactory-server:
    container_name: 'satisfactory-server'
    hostname: 'satisfactory-server'
    image: 'wolveix/satisfactory-server:latest'
    ports:
      - '7777:7777/tcp'
      - '7777:7777/udp'
      - '8888:8888/tcp'
    volumes:
      - './satisfactory-server:/config'
      - './certs/live/${DOMAIN}/fullchain.pem:/config/gamefiles/FactoryGame/Certificates/cert_chain.pem'
      - './certs/live/${DOMAIN}/privkey.pem:/config/gamefiles/FactoryGame/Certificates/private_key.pem'
    environment:
      - MAXPLAYERS=4
      - PGID=1000
      - PUID=1000
      - STEAMBETA=false
    restart: unless-stopped
    depends_on:
      certbot:
        condition: service_completed_successfully
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 4G

  certbot:
    image: certbot/certbot
    command: certonly --standalone --non-interactive --agree-tos -m ${CERTBOT_MAIL} -d ${DOMAIN}
    ports:
      - '80:80/tcp'
    volumes:
      - ./certs:/etc/letsencrypt
    environment:
      - CERTBOT_MAIL=certbot@domain.tld
      - DOMAIN=satisfactory.domain.tld
```

The `docker-compose.yml` file above should replace the `docker-compose.yml` file you already have configured. Adjust the
`CERTBOT_MAIL` and `DOMAIN` environment variables under the `certbot` service to be a real email address, and the domain
you'd like to issue the SSL certificate for. Ensure prior to running this that you've already created the necessary DNS
record for your domain. If you don't certbot will fail, and you'll likely hit your rate limit and need to wait a while
to try again (check the `certbot` container's logs for further information).

**Ensure that you open/port forward for port `80/tcp`.**

You can now launch the Docker Compose configuration in the same way you normally would. Do note that if Certbot fails,
the game server will not start.

Note the `certbot` command above only issues the cert once (`certonly`) — it does not renew it. You'll need to
re-run it (or set up your own renewal loop) before the cert expires.

## Reusing an Existing Reverse Proxy's Cert

If you already run a reverse proxy (Nginx Proxy Manager, Traefik, Caddy, etc.) that's issuing and renewing a
Let's Encrypt cert for you, you don't need Certbot above — point the game container at that proxy's cert store
directly.

**Mount the cert *directory*, not individual files.** Most ACME clients store the live cert as a symlink into
a versioned archive folder, and repoint that symlink on renewal. Compose's single-file bind mounts (as used in
the Certbot example above) resolve the symlink once at container start and pin to that file — renewals silently
go stale until you recreate the container. Mounting the whole directory keeps it live, since the symlink gets
re-resolved on every read.

The game process itself still only reads the cert once at startup, so **you'll need to restart the container
periodically** to pick up a renewed cert (a weekly cron is plenty, since renewal happens ~30 days before
expiry):

```
0 4 * * 0 docker restart satisfactory-server
```

### Nginx Proxy Manager

Find your cert's ID under `<npm-data>/letsencrypt/live/` (e.g. `npm-8`) — check the `fullchain.pem` /
`privkey.pem` symlinks in each folder, or match domains with:

```shell
openssl x509 -in <npm-data>/letsencrypt/live/npm-N/cert.pem -noout -subject -ext subjectAltName
```

`docker-compose.yml`:

```yaml
services:
  satisfactory-server:
    # ...
    volumes:
      - './satisfactory-server:/config'
      - '/path/to/npm/letsencrypt:/etc/letsencrypt:ro'
```

One-time, point the game's cert paths at NPM's live symlinks (this lives on your own `/config` bind mount, so
it persists across container recreates):

```shell
CERT_DIR="./satisfactory-server/gamefiles/FactoryGame/Certificates"
mkdir -p "$CERT_DIR"
ln -sfn /etc/letsencrypt/live/npm-N/fullchain.pem "$CERT_DIR/cert_chain.pem"
ln -sfn /etc/letsencrypt/live/npm-N/privkey.pem "$CERT_DIR/private_key.pem"
```

Replace `npm-N` with your cert's ID. NPM's container doesn't have docker.sock, so it can't restart the
Satisfactory container itself — use the host cron shown above.

### Traefik

Traefik doesn't store certs as separate PEM files by default — everything lives in one `acme.json`. Run
[`traefik-certs-dumper`](https://github.com/ldez/traefik-certs-dumper) as a sidecar to split it into
per-domain PEM files on a watch loop:

```yaml
services:
  satisfactory-server:
    # ...
    volumes:
      - './satisfactory-server:/config'
      - './certs-dump:/etc/certs-dump:ro'

  certs-dumper:
    image: 'ldez/traefik-certs-dumper:latest'
    command: 'file --version v2 --watch --source /data/acme.json --dest /output'
    volumes:
      - '/path/to/traefik/acme.json:/data/acme.json:ro'
      - './certs-dump:/output'
    restart: unless-stopped
```

This produces `./certs-dump/<domain>/{fullchain,privkey}.pem`, updated live as Traefik renews. One-time:

```shell
CERT_DIR="./satisfactory-server/gamefiles/FactoryGame/Certificates"
mkdir -p "$CERT_DIR"
ln -sfn /etc/certs-dump/<domain>/fullchain.pem "$CERT_DIR/cert_chain.pem"
ln -sfn /etc/certs-dump/<domain>/privkey.pem "$CERT_DIR/private_key.pem"
```

Replace `<domain>` with the hostname you issued the cert for.

## Troubleshooting

### I can't reach the server with the new cert!

If you could reach the server before configuring a signed SSL cert, ensure that you're not doing either of the 
following:
- Using a wildcard cert: Satisfactory does not support them ([#354](https://github.com/wolveix/satisfactory-server/issues/354))
- Connecting to a hostname not specified in your cert: Satisfactory does not support this ([#354](https://github.com/wolveix/satisfactory-server/issues/354))
- Using your local IP. You cannot use your local IP, as it will not be included in your certificate.

### What if port 80 is already in-use with a reverse-proxy?

Change the port for the certbot service (e.g. `7800:80/tcp`), and forward HTTP traffic from your reverse proxy through
to your `certbot` container.

Here are examples on how you can do this with Caddy and NGINX

#### Caddy

Modify your Caddyfile to include your given domain above. Ensure that you put `http://` **before** the domain, otherwise
Caddy will _also_ request an SSL certificate for it.

```
http://satisfactory.domain.tld {
    reverse_proxy :7780
}
```


#### NGINX

Modify your NGINX configuration file to include the following virtual host:

```
server {
    listen       80;
    server_name  satisfactory.domain.tld;

    location / {
        proxy_pass  http://localhost:7780;
    }
}
```
