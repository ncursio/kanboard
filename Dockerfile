FROM alpine:3.24

LABEL org.opencontainers.image.source="https://github.com/kanboard/kanboard" \
    org.opencontainers.image.title="Kanboard" \
    org.opencontainers.image.description="Kanboard is project management software that focuses on the Kanban methodology" \
    org.opencontainers.image.vendor="Kanboard" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://kanboard.org" \
    org.opencontainers.image.documentation="https://docs.kanboard.org"

# Upstream also declares /etc/nginx/ssl as a VOLUME -- found live: on Fly's Machine
# runtime this makes the self-signed cert entrypoint.sh generates on every boot
# (openssl req ... -out /etc/nginx/ssl/kanboard.crt) not actually land where nginx
# expects it, so nginx fails to start at all ("cannot load certificate", BIO_new_file
# failed) and the container crash-loops. Fly's own edge already terminates TLS for
# external traffic and nothing here needs this path to persist across restarts
# (shared demo instance, no persistence model), so dropping it from VOLUME entirely
# is simpler and more robust than debugging Fly's anonymous-volume semantics.
VOLUME ["/var/www/app/data", "/var/www/app/plugins"]

EXPOSE 80 443

ARG VERSION

RUN apk --no-cache --update add \
    tzdata openssl unzip nginx bash ca-certificates s6 curl ssmtp mailx php84 php84-phar php84-curl \
    php84-fpm php84-json php84-zlib php84-xml php84-dom php84-ctype php84-opcache php84-zip php84-iconv \
    php84-pdo php84-pdo_mysql php84-pdo_sqlite php84-pdo_pgsql php84-mbstring php84-session php84-bcmath \
    php84-gd php84-openssl php84-sockets php84-posix php84-ldap php84-simplexml php84-xmlwriter && \
    rm -rf /var/www/localhost && \
    rm -f /etc/php84/php-fpm.d/www.conf && \
    ln -sf /usr/bin/php84 /usr/bin/php

# Found live, second pass: dropping the VOLUME declaration alone wasn't enough -- the
# directory itself was never actually created by nginx's own package install, so the
# entrypoint's self-signed cert generation (openssl req ... -out
# /etc/nginx/ssl/kanboard.crt) still had nowhere to write and nginx still crash-looped
# the exact same way. Create the real directory here so it unambiguously exists in the
# image regardless of volume/mount semantics.
RUN mkdir -p /etc/nginx/ssl

ADD . /var/www/app
ADD docker/ /

RUN rm -rf /var/www/app/docker && echo $VERSION > /var/www/app/app/version.txt

HEALTHCHECK --start-period=3s --timeout=5s \
  CMD curl -f http://localhost/healthcheck.php || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
