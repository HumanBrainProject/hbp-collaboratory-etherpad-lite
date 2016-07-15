FROM node:5

# Dependencies (alphabetically sorted)
# Etherpad Lite basics: build-essential curl gzip libssl-dev pkg-config python
# More import format abiword
RUN apt-get update && apt-get install -y \
  abiword \
  build-essential \
  curl \
  gzip \
  libssl-dev \
  pkg-config \
  python

COPY etherpad-lite /etherpad-lite

# Ensure we are not leaking sensible files
WORKDIR /etherpad-lite
RUN rm -rf src/settings.json
RUN rm -rf node_modules && npm install && cd src && rm -rf node_modules

COPY etherpad-lite/settings.json.template /conf/settings.json
COPY package.json /etherpad-lite/package.json

RUN npm install
RUN bin/installDeps.sh

VOLUME /conf
EXPOSE 9001

CMD ["bin/run.sh", "--settings", "/conf/settings.json", "--root"]
