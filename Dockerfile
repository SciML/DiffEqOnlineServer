# Start with 0.5.0 which is also latest at the moment
FROM julia:0.5.0

# Install stuff needed by the HttpParser package
RUN apt-get update && apt-get install -y \
    zip \
    unzip \
    build-essential \
    make \
    gcc \
    libzmq3-dev


# Make package folder and install everything in require
# No, I don't know why we need two Pkg.resolve's...
RUN julia -e "Pkg.resolve()"
COPY REQUIRE /root/.julia/v0.5/REQUIRE
RUN julia -e "Pkg.resolve()"

# Build some stuff that needs to be built separately -- breaking these out one-by-one allows easier modification since all builds prior to a change in the Dockerfile will be cached
RUN julia -e 'Pkg.build("ZMQ")'
RUN julia -e 'Pkg.build("Rmath")'
RUN julia -e 'Pkg.build("StatsFuns")'
RUN julia -e 'Pkg.build("Sundials")'
RUN julia -e 'Pkg.build("JuliaWebAPI")'
RUN julia -e 'Pkg.build("PlotlyJS")'
RUN julia -e 'Pkg.build("Plots")'

# Run a test script
# COPY test.jl /test.jl
# ENTRYPOINT julia test.jl

# Run the real server
COPY /api /api
EXPOSE 7777
COPY start_both.sh /start_both.sh
ENTRYPOINT /bin/bash start_both.sh
