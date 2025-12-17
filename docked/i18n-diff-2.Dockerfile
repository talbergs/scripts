FROM python:3.11-alpine

# Install system dependencies
RUN apk add --no-cache \
    bash \
    git \
    tar \
    findutils \
    build-base \
    && rm -rf /var/cache/apk/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    tree-sitter==0.22.2 \
    tree-sitter-php==0.23.0

# Configure git to trust any directory (safe for isolated container)
RUN git config --global --add safe.directory '*'

# Create working directory
WORKDIR /workspace

# Copy the Python script
COPY i18n-diff-2.py /usr/local/bin/i18n-diff-2
COPY i18n-diff-2.sh /usr/local/bin/check-strings

# Make scripts executable
RUN chmod +x /usr/local/bin/i18n-diff-2 /usr/local/bin/check-strings

# Set bash as default shell
SHELL ["/bin/bash", "-c"]

# Set the entrypoint to the bash wrapper for compatibility
ENTRYPOINT ["/usr/local/bin/check-strings"]

# Default command shows help
CMD ["-h"]
