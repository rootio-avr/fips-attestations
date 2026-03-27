FROM cr.root.io/redis:7.2.4-alpine-3.19-fips

# Copy demo configurations
COPY configs/ /opt/demos/configs/

# Copy demo scripts (with execute permissions)
COPY --chmod=0755 scripts/ /opt/demos/scripts/

# Copy sample HTML content
COPY html/ /opt/demos/html/

# Expose ports
EXPOSE 6379

# Add labels
LABEL description="Redis FIPS Demo Image - Interactive FIPS 140-3 configuration examples"
LABEL version="1.0"
LABEL redis.version="7.2.4"
LABEL wolfssl.version="5.8.2"
LABEL fips.certificate="#4718"

# Use the base image entrypoint
# Users can override the config with: docker run -v $(pwd)/custom.conf:/etc/redis/redis.conf ...
CMD ["redis-server"]
