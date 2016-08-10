# HBP Deployment Guide

Due to the future migration of our IT, I preferred to deploy the solution using
a Docker container, deployed mostly manually through a composition of two
containers.

This guide include all sources and explanation to recreate the same environment
on a new instance as well.

## Bootstrap the environment

1. Create a Ubuntu, Debian or RHEL7 host
2. Use docker_host puppet recipe to provision the host
3. Ensure the system is up to date (I used docker 1.12 for e.g.)
4. Ensure docker-compose is installed with `pip install docker-host --upgrade -i https://bbpteam.epfl.ch/repository/devpi/simple`. You might want to create a virtual environment
for this as RHEL7 is using python 2.7 for some of its scripts (I did not).

The following steps are explained in greater details.

### Create a private docker registry

The following will let you create a *unsecure* registry which must be
only accessible by trusted people. You can read more about the docker private
registry on their [official site](https://docs.docker.com/registry/).

First, pull the Docker registry image with `docker pull` command.

``` bash
docker pull registry:2
```

Then, create a self signed certificate for your registry ([guide](https://devcenter.heroku.com/articles/ssl-certificate-self)) that you
will use for the registry as it must support https access. I put mine in
`~/docker-registry-conf/certs/domain.key` and `~/docker-registry-conf/certs/domain.crt`

Create the registry configuration file. I used this one:

`~/docker-registry-conf/config.yml`:

```yaml
version: 0.1
log:
  fields:
    service: registry
storage:
    cache:
        blobdescriptor: inmemory
    filesystem:
        rootdirectory: /var/lib/registry
http:
    addr: :5000
    headers:
        X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
proxy:
  remoteurl: https://registry-1.docker.io
```

I used the following script to run the docker instance. If you want to reuse it,
please update the environment variables:
- `V_DATA`: the folder in which the layers and images will be stored
- `V_CONFIG`: the folder where the registry configuration is located
- `V_CERTS`: the folder where the generated SSL certificate are stored
- `PORT`: the host port that will expose the registry

Also check that `REGISTRY_HTTP_TLS_CERTIFICATE` and `REGISTRY_HTTP_TLS_KEY` will
match your own cert files.

`~/create_registry.sh`:

```bash
#! /bin/bash

export V_DATA=/root/docker-registry-data
export V_CONFIG=/root/docker-registry-conf/config.yml
export V_CERTS=/root/docker-registry-conf/certs
export PORT=5000
docker run -d -p $PORT:5000 --restart=always --name registry -v $V_DATA:/var/lib/registry -v $V_CONFIG:/var/lib/registry/config.yml:ro -v $V_CERTS:/certs -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key registry:2

# Alternate command to run the container interactively and remove it on stop -- for debugging purpose.
# docker run -p $PORT:5000 --rm -it --name registry -v $V_DATA:/var/lib/registry -v $V_CERTS:/certs -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key registry:2
```


### Deploy the etherpad-lite-hbp docker image

To push your `etherpad-lite-hbp` Docker image to your registry, you must tag it
properly. If your registry is served at `bbpsrvi16.epfl.ch:5000`, the tag should
be `bbpsrvi16.epfl.ch:5000/etherpad-lite-hbp:latest`. Note that latest will
be overrode every time, a better practice would be to manage different versions
using a tag like `bbpsrvi16.epfl.ch:5000/etherpad-lite-hbp:1.1`. Example docker
command:

```bash
docker tag 7878edd bbpsrvi16.epfl.ch:5000/etherpad-lite-hbp:latest
docker push bbpsrvi16.epfl.ch:5000/etherpad-lite-hbp:latest
```

To push to this private registry, you need to add bbpsrvi16.epfl.ch:5000 to the
list of `--insecure-host` ([learn more](https://docs.docker.com/registry/insecure/#/using-self-signed-certificates)).
On some system, you also need to install and trust the SSL certificate for this VM.

You can dowload the certificate from
ssh://bbpsrvi16.epfl.ch:/root/docker-registry-conf/certs

You need to generate the etherpad configuration file, using the model in this
project `conf/settings.json`. At least the database fields and the oauth2
settings should be provided. Here is the version I used, minus the secret fields:

`~/etherpad-deploy/conf/etherpad-conf/settings.json`

```json
{
  "dbSettings" : {
    "user"    : "etherpad_lite",
    "host"    : "bbpdbsrv05.epfl.ch",
    "password": "XXX",
    "database": "etherpad_lite",
    "charset" : "utf8mb4"
  },
  "users": {
    "oauth2": {
      "authorizationURL": "https://services.humanbrainproject.eu/oidc/authorize",
      "tokenURL": "https://services.humanbrainproject.eu/oidc/token",
      "userinfoURL": "https://services.humanbrainproject.eu/oidc/userinfo",
      "usernameKey": "name",
      "useridKey": "preferred_username",

      "clientID": "XXX-CLIENT_ID",
      "clientSecret": "XXX-CLIENT_SECRET",
      "publicURL": "https://developer.humanbrainproject.eu/etherpad"
    }
  },
  "title": "Etherpad",
  "defaultPadText" : "Welcome to Etherpad!\n\nThis pad text is synchronized as you type, so that everyone viewing this page sees the same text. This allows you to collaborate seamlessly on documents!\n\nGet involved with Etherpad at http:\/\/etherpad.org\n",
  "padOptions": {
    "noColors": false,
    "showControls": true,
    "showChat": false,
    "showLineNumbers": true,
    "useMonospaceFont": false,
    "userName": false,
    "userColor": false,
    "rtl": false,
    "alwaysShowChat": false,
    "chatAndUsers": false,
    "lang": "en-gb"
  },
  "requireAuthentication" : true,
  "requireAuthorization" : true,
  "trustProxy" : true,
  "favicon": "favicon.ico",
  "ip": "0.0.0.0",
  "port" : 9001,
  "toolbar": {
    "left": [
      ["bold", "italic", "underline", "strikethrough"],
      ["orderedlist", "unorderedlist", "indent", "outdent"],
      ["undo", "redo"],
      ["clearauthorship"]
    ],
    "right": [
      ["timeslider", "savedrevision"],
      ["showusers"]
    ],
    "timeslider": [
      ["timeslider_export", "timeslider_returnToPad"]
    ]
  },
  "showSettingsInAdminPage" : true,
  "suppressErrorsInPadText" : false,
  "requireSession" : false,
  "editOnly" : false,
  "sessionNoPassword" : false,
  "minify" : true,
  "maxAge" : 21600,
  "abiword" : null,
  "soffice" : null,
  "tidyHtml" : null,
  "allowUnknownFileEnds" : true,
  "disableIPlogging" : false,
  "socketTransportProtocols" : ["xhr-polling", "jsonp-polling", "htmlfile"],
  "loadTest": false,
  "loglevel": "INFO",
  "logconfig" :
    { "appenders": [
        { "type": "console" }
      ]
    }
}
```

As we are serving the Etherpad instance from `https://developer.humanbrainproject.eu/etherpad/`
and that our load balancer require that the relative path remains identical, we need to use
a reverse proxy to rewrite the path and the redirection sent from etherpad. We use the
`jwilder/nginx-proxy` Docker image for doing so. It still require some customisation
to handle the rewrites. They have been done in a Nginx vhost.d config file.

`~/etherpad-deploy/conf/vhost.d/developer.humanbrainproject.eu`

```nginx
location ~* ^/etherpad/ {
  rewrite ^/etherpad/(.*) /$1 break;
  proxy_set_header Host              $host;
  proxy_set_header X-Forwarded-Proto $scheme;
  proxy_redirect   /                 https://$host/etherpad/;
  proxy_pass http://etherpad-lite-server:9001;
}
```

To instantiate the two docker containers, I used the following docker-compose.yml
file. As they are very domain specific, please ensure that all value match your
deployment.

`~/etherpad-deploy/docker-compose.yml`:

```yaml
# etherpad-lite behind a nginx proxy
version: '2'
services:
  nginx-proxy:
    image: jwilder/nginx-proxy
    links:
      # used in the nginx vhost conf file
      - etherpad-lite:etherpad-lite-server
    environment:
      - DEFAULT_HOST=developer.humanbrainproject.eu
    ports:
      - "9000:80"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./conf/vhost.d:/etc/nginx/vhost.d:ro
    network_mode: bridge # to work with the puppet managed iptable
    restart: always
  etherpad-lite:
    image: bbpsrvi16.epfl.ch:5000/etherpad-lite-hbp:latest
    environment:
      - VIRTUAL_HOST=developer.humanbrainproject.eu
    volumes:
      - ./conf/etherpad-conf:/conf
    network_mode: bridge # to work with the puppet managed iptable
    restart: always
```

Run `docker-compose` to start the golem, below in detached mode.

```bash
docker-compose up -d
```

Check that everything is working:

```bash
docker ps
```
