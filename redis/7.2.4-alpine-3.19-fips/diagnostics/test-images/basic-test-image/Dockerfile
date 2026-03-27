################################################################################
# Redis FIPS Test Image
# Based on the actual Redis FIPS image we built
################################################################################
FROM cr.root.io/redis:7.2.4-alpine-3.19-fips

# Switch to root for testing (needed to start Redis daemon)
USER root

# Copy test scripts (no additional packages needed - use what's in the image)
COPY test-suite.sh /test-suite.sh
RUN chmod +x /test-suite.sh

# Override entrypoint for testing
ENTRYPOINT ["/bin/sh"]
CMD ["/test-suite.sh"]
