FROM alpine:3.19

# Install required dependencies
RUN apk add --no-cache \
    bash \
    git \
    tar \
    gettext \
    findutils \
    sed \
    gawk \
    grep \
    diffutils \
    coreutils

# Create a working directory
WORKDIR /workspace

# Copy the script into the container
COPY i18n-diff.sh /usr/local/bin/check-strings

# Make the script executable
RUN chmod +x /usr/local/bin/check-strings

# Configure git to trust any directory (safe for isolated container)
RUN git config --global --add safe.directory '*'

# Set bash as the default shell
SHELL ["/bin/bash", "-c"]

# Set the entrypoint to the script
ENTRYPOINT ["/usr/local/bin/check-strings"]

# Default command shows help
CMD ["-h"]

