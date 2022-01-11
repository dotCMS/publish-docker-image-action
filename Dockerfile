FROM docker:20.10.11-dind

WORKDIR /srv

RUN apk --update add bash git curl \
  && rm -rf /var/cache/apk/*

COPY build-src/entrypoint.sh /srv
COPY build-src/publishDockerImage.sh /srv
RUN find /srv/ -type f -name "*.sh" -exec chmod a+x {} \;

ENTRYPOINT ["/srv/entrypoint.sh"]
