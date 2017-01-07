# Start with 0.5.0 which is also latest at the moment
FROM julia:0.5.0

# Make package folder and install everything in require
RUN julia -e "Pkg.resolve()"
