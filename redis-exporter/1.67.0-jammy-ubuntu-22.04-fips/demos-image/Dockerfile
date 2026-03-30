# Redis Exporter FIPS Demo Image
#
# Purpose: Interactive demonstration container for redis_exporter FIPS image
# Base: cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips
#
# Build: ./build.sh
# Run: docker run --rm redis-exporter-demos:latest
#
################################################################################

FROM cr.root.io/redis-exporter:1.67.0-jammy-ubuntu-22.04-fips

# Switch to root for setup
USER root

################################################################################
# Copy Demo Files
################################################################################
# Copy all demo configurations, scripts, and HTML dashboard
# NOTE: test-metrics.sh requires curl, run it from host machine
################################################################################

# Copy demo configurations
COPY configs/ /demo/configs/

# Copy demo scripts (with execute permissions)
COPY --chmod=0755 scripts/ /demo/scripts/

# Copy HTML dashboard
COPY html/ /demo/html/

# Create directories for demo artifacts
RUN mkdir -p /demo/certs /demo/data /demo/logs && \
    chown -R redis-exporter:redis-exporter /demo

################################################################################
# Labels
################################################################################

LABEL description="Redis Exporter FIPS Demo Image - Interactive FIPS 140-3 demonstrations"
LABEL version="1.0"
LABEL redis-exporter.version="1.67.0"
LABEL base.image="jammy-ubuntu-22.04-fips"
LABEL wolfssl.version="5.8.2"
LABEL wolfssl.fips.certificate="#4718"
LABEL fips.mode="enabled"
LABEL demo.scenarios="basic,sentinel,cluster,monitoring,tls,fips-validation"

################################################################################
# Environment Variables
################################################################################

ENV DEMO_HOME=/demo
ENV DEMO_CONFIGS=/demo/configs
ENV DEMO_SCRIPTS=/demo/scripts
ENV DEMO_HTML=/demo/html

################################################################################
# Expose Ports
################################################################################

EXPOSE 9121

################################################################################
# Entrypoint & Default Command
################################################################################
# Entrypoint runs as root to fix permissions, then drops to redis-exporter user
# This allows volume mounts to work without --user flag
# Default CMD runs test orchestration script with FIPS-only mode (no dependencies)
# For metrics tests, use: --install-curl --all flags
# For full demo with Redis, use docker-compose (see README.md)
################################################################################

WORKDIR /demo

# Stay as root for entrypoint (will drop privileges inside entrypoint script)
ENTRYPOINT ["/demo/scripts/docker-entrypoint.sh"]
CMD ["/demo/scripts/test-demos.sh", "--fips-only"]
