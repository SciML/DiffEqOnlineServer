#!/bin/bash
cd api
echo 'Starting run_api.jl'
julia run_api.jl &
echo 'Waiting 30 sec for it to spin up'
sleep 30
echo 'Starting srvr.jl'
julia srvr.jl
