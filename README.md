# Etherpad Lite HBP Edition

This project aim to build a Docker Image that bundle Etherpad
with plugins for the HBP Collaboratory.


## Build

Build the image using Docker `docker` command.

```bash
docker build . --tag etherpad-lite-hbp
```


## Run the container

The container environment must be configured.

### The `settings.json` file should be customized

The container should be provided with a `VOLUME` containing a customized
`settings.json`. An example can be found in `./conf/settings.json`. You should
modify the example with proper `users` and `database` declarations.

#### Configure `users` to be authorized with `oauth2`

Find the commented `users` section and create one according to the documentation
of ep_oauth2. Here is an example with all the correct values for HBP domain.
The three last configuration are needs to be updated given your environment.

```json
"users": {
  "oauth2": {
    "authorizationURL": "https://services.humanbrainproject.eu/oidc/authorize",
    "tokenURL": "https://services.humanbrainproject.eu/oidc/token",
    "userinfoURL": "https://services.humanbrainproject.eu/oidc/userinfo",
    "usernameKey": "name",
    "useridKey": "preferred_username",

    "clientID": "YOUR-OIDC-CLIENT-ID",
    "clientSecret": "YOUR-OIDC-CLIENT-SECRET",
    "publicURL": "http://localhost:9001"
  }
}
```

#### Configure `database` to a production instance

By default, Etherpad-lite run with DirtyDB, a filesystem DB that you don't want
to rely on. Instead, configure a proper MySQL instance (Postgres is reported to
work as well). There is an good example in the `settings.json` file.
Uncomment it and replace the value given your environement.

### Run the container from your development docker instance

This command will run the container locally.

```bash
docker run --rm -it --name etherpad -p 9001:9001 -v $(pwd)/conf:/conf etherpad-lite-hbp

# -rm remove the container on stop
# -it interactive mode
```

You can know connect to the port `9001` of your docker host.


# Push to release

You can push the generated image to bbpsrvi16.epfl.ch:5000. You must be part
of the EPFL network to do so and add bbpsrvi16.epfl.ch:5000 in the list
of --insecure-host as it use a self signed certificate.

You can dowload the certificate from
ssh://bbpsrvi16.epfl.ch:/root/docker-registry-conf/certs

To release, run:

```bash
docker build
docker tag --tag bbpsrvi16.epfl.ch:5000/etherpad-lite-hbp:latest
docker push bbpsrvi16.epfl.ch:5000/etherpad-lite-hbp:latest
```
