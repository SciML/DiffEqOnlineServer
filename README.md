# DiffEqOnlineServer

This repo includes the dockerfile for the back-end of the DiffEqOnline web site.  It's in its own repo to make pushing to various hosting systems easier.  This could probably be set to private but I don't think it matters.  

## Building the image
From the root folder of this repository I'm running something like

```
docker build --no-cache -t diffeqonline-server:0.1.0 .
```

where the --no-cache option should probably be turned off unless something changed in the REQUIRE file recently.  
