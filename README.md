# DiffEqOnlineServer

This is the back-end that powers [http://app.juliadiffeq.org/](http://app.juliadiffeq.org/).  The front-end is in a different repository, at [https://github.com/JuliaDiffEq/DiffEqOnline](https://github.com/JuliaDiffEq/DiffEqOnline).

## Development notes

### Running the server locally

```
julia ./api/mux_server.jl 7777
```

where 7777 is the port you want it to host on. You can then access it at [http://localhost:7777](http://localhost:7777).

### Building the Docker image

Run

```
docker build -t diffeqonline-server .
```

You can run the image with

```
docker run -i -t --rm -p 7777:7777 -e PORT=7777 diffeqonline-server
```

which will host it at [http://192.168.99.100:7777](http://192.168.99.100:7777/) rather than at localhost.  The IP might vary.  

You can run a interactive version of the container and not start the server with

```
docker run -dit -p 7777:7777 --entrypoint=/bin/bash diffeqonline-server
```

This does still open up the port in case you want to run some testing.

### Deploying to Heroku

General instructions can be found [here](https://devcenter.heroku.com/articles/container-registry-and-runtime), but it's pretty much just

```
heroku container:deploy
```

or

```
heroku container:push web --app AppName
```
