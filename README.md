# DiffEqOnlineServer

This repo includes the dockerfile for the back-end of the DiffEqOnline web site.  It's in its own repo to make pushing to various hosting systems easier.  This could probably be set to private but I don't think it matters.  

## Building the image
From the root folder of this repository I'm running something like

```
docker build -t diffeqonline-server .
```

If something changed in the REQUIRE file recently you may need to use the `--no-cache` option.

You can run the image with

```
docker run -i -t --rm -p 7777:7777 diffeqonline-server
```

which should launch the two portions of the server.  You can then test it by going to something like [http://192.168.99.100:7777/squareit/WzEsMiwzXQ==](http://192.168.99.100:7777/squareit/WzEsMiwzXQ==) where you might need to change the IP.

You can run a interactive version of the container and not start the server with

```
docker run -dit -p 7777:7777 --entrypoint=/bin/bash diffeqonline-server
```

(This does still open up the port in case you want to run some testing.)

Right now the server seems to be working properly but calling the ode endpoint with the default ODE, `srvr.jl` appears to error out at `f = ode_def_opts(name, opts, ex, params...)`.  We can't see the error since JuliaWebAPI squashes it.  
