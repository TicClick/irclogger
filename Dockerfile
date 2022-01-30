# syntax=docker/dockerfile:1.3-labs
# ^ https://www.docker.com/blog/introduction-to-heredocs-in-dockerfiles/

FROM ubuntu:21.04

ARG CONTAINER_ROOT
ARG DOMAIN
ARG OSU_USERNAME
ARG OSU_PASSWORD

ENV CONTAINER_ROOT ${CONTAINER_ROOT}
ENV DOMAIN ${DOMAIN}
ENV OSU_USERNAME ${OSU_USERNAME}
ENV OSU_PASSWORD ${OSU_PASSWORD}

WORKDIR $CONTAINER_ROOT
# this assumes that Dockerfile is located in the application's root directory
COPY . .
COPY ./config/init.d/* /etc/init.d/

EXPOSE 80 8080

RUN adduser --disabled-password --gecos "" irclog
RUN chown -R irclog:irclog $CONTAINER_ROOT
RUN chmod -R a+r $CONTAINER_ROOT

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    tzdata \
    ruby-full git \
    postgresql postgresql-contrib libpq-dev \
    redis-server \
    openssl build-essential sudo less ncal \
    nginx

RUN service postgresql start && \
    sudo -u postgres createuser irclog --superuser && \
    sudo -u irclog createdb irclog && \
    echo 'CREATE EXTENSION IF NOT EXISTS btree_gin' | sudo -u irclog psql --dbname irclog && \
    sudo -u irclog psql --dbname irclog --file $CONTAINER_ROOT/config/sql/postgresql-schema.sql

# workaround for https://github.com/moby/buildkit/issues/2439 which allows for variable expansion
RUN cat > config/application.yml <<EOF
---
database: postgres:///irclog?user=irclog
redis: redis://localhost:6379
watchdog:
  timeout: 180
domain: "$DOMAIN"
server: cho.ppy.sh
username: "$OSU_USERNAME"
password: "$OSU_PASSWORD"
channels:
  - "#announce"
  - "#arabic"
  - "#balkan"
  - "#bulgarian"
  - "#cantonese"
  - "#chinese"
  - "#ctb"
  - "#czechoslovak"
  - "#dutch"
  - "#english"
  - "#filipino"
  - "#finnish"
  - "#french"
  - "#german"
  - "#greek"
  - "#hebrew"
  - "#help"
  - "#hungarian"
  - "#indonesian"
  - "#italian"
  - "#japanese"
  - "#korean"
  - "#lobby"
  - "#malaysian"
  - "#mapping"
  - "#modreqs"
  - "#osu"
  - "#osumania"
  - "#polish"
  - "#portuguese"
  - "#romanian"
  - "#russian"
  - "#skandinavian"
  - "#spanish"
  - "#taiko"
  - "#thai"
  - "#turkish"
  - "#ukrainian"
  - "#videogames"
  - "#vietnamese"
EOF

# this relies on an existing symbolic link,
#  /etc/nginx/sites-enabled/default -> /etc/nginx/sites-available/default
# nginx only runs in the container, so to expose the logger you'll need to run nginx on the host as well
COPY <<EOF /etc/nginx/sites-available/default
upstream irclogger {
  server unix:${CONTAINER_ROOT}/tmp/viewer.sock;
}

server {
  listen 80;
  listen [::]:80;
  server_name ${DOMAIN};

  root ${CONTAINER_ROOT}/public;

  location / {
    if (!-f \$request_filename) {
      proxy_pass http://irclogger;
    }
  }
}
EOF

# USER root
# the below RUN commands assume all configs are modified as necessary
RUN gem install bundler:2.1.4 && bundle install --deployment --without mysql
RUN ln -s /usr/local/bin/bundle /usr/bin/bundle 
RUN update-rc.d irclogger-logger defaults && update-rc.d irclogger-viewer defaults

CMD service postgresql start && \
    service redis-server start && \
    service nginx start && \
    service irclogger-logger start && service irclogger-viewer start && \
    sleep inf
