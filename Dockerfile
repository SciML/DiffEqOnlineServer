# Start with 0.5.0 which is also latest at the moment
FROM julia:0.5.0

# Make package folder and install everything in require
# No, I don't know why we need two Pkg.resolve's...
RUN julia -e "Pkg.resolve()"
COPY REQUIRE /root/.julia/v0.5/REQUIRE
RUN julia -e "Pkg.resolve()"
