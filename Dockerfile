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

# Build all the things
RUN julia -e 'Pkg.build()'

# Build those things which are mysteriously not included in the list of all things
RUN julia -e 'Pkg.build("Plots")'
RUN julia -e 'Pkg.build("SymEngine")'


# Run the real server
COPY /api /api
# EXPOSE 7777

# Don't run as root
# RUN useradd -ms /bin/bash myuser
# USER myuser

CMD julia /api/mux_server.jl $PORT
