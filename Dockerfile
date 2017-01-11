# Start with 0.5.0 which is also latest at the moment
FROM julia:0.5.0

# Install stuff needed by the HttpParser package
RUN apt-get update && apt-get install -y \
    zip \
    unzip \
    build-essential \
    make \
    gcc \
    libzmq3-dev \
    subversion

# Make package folder and install everything in require
ENV JULIA_PKGDIR=/opt/julia
RUN julia -e "Pkg.init()"
COPY REQUIRE /opt/julia/v0.5/REQUIRE
RUN julia -e "Pkg.resolve()"

# Build all the things
RUN julia -e 'Pkg.build()'

# Build those things which are mysteriously not included in the list of all things, then use all modules to force precompile
RUN julia -e 'Pkg.build("Plots"); Pkg.build("SymEngine"); Pkg.rm("Conda")'

# Force precompile of all modules -- this should greatly improve startup time
RUN julia -e 'using DiffEqBase, OrdinaryDiffEq, ParameterizedFunctions, Plots, Mux, JSON, HttpCommon'

# Run the real server -- eventually grab this from the other repo via svn as described here: http://stackoverflow.com/questions/7106012/download-a-single-folder-or-directory-from-a-github-repo
COPY /api /api
# EXPOSE 7777

# Don't run as root
RUN useradd -ms /bin/bash myuser
RUN chown -R myuser:myuser /opt/julia
USER myuser

CMD julia /api/mux_server.jl $PORT
