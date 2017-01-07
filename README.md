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
docker run diffeqonline-server
```

but at the moment it exits immediately.  To get an interactive shell in that image run

```
docker run -dit diffeqonline-server
```

which starts an interactive instance which you can then connect to.  
