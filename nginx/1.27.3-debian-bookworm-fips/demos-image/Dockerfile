FROM cr.root.io/nginx:1.27.3-debian-bookworm-fips

# Copy demo configurations
COPY configs/ /opt/demos/configs/

# Copy sample HTML content
COPY html/ /opt/demos/html/

# Copy default demo config
COPY configs/reverse-proxy.conf /etc/nginx/nginx.conf

# Create demo directories
RUN mkdir -p /usr/share/nginx/html/demos \
    && cp -r /opt/demos/html/* /usr/share/nginx/html/demos/ \
    && chown -R nginx:nginx /usr/share/nginx/html/demos

# Expose ports
EXPOSE 80 443

# Add labels
LABEL description="Nginx FIPS Demo Image - Interactive FIPS 140-3 configuration examples"
LABEL version="1.0"
LABEL nginx.version="1.27.3"
LABEL wolfssl.version="5.8.2"
LABEL fips.certificate="#4718"

# Use the base image entrypoint
# Users can override the config with: docker run -v $(pwd)/custom.conf:/etc/nginx/nginx.conf ...
CMD ["nginx", "-g", "daemon off;"]
