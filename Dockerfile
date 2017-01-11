# Start with 0.5.0 which is also latest at the moment
FROM julia:0.5.0

# Install stuff needed by the HttpParser package
RUN apt-get update && apt-get install -y \
    zip \
    unzip \
    build-essential \
    make \
    gcc \


# Make package folder and install everything in require
# No, I don't know why we need two Pkg.resolve's...
RUN julia -e "Pkg.resolve()"

# Build all the things
RUN julia -e 'Pkg.build()'



COPY /api /api
# EXPOSE 7777

# Don't run as root

CMD julia /api/mux_server.jl $PORT
