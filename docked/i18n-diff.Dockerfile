# Stage 1: Build tree-sitter CLI and PHP grammar
FROM rust:alpine AS builder

RUN apk add --no-cache \
    musl-dev \
    git \
    nodejs \
    npm

# Install tree-sitter CLI
RUN cargo install tree-sitter-cli --version 0.22.6

# Clone and build PHP grammar
WORKDIR /grammars
RUN git clone --depth 1 https://github.com/tree-sitter/tree-sitter-php.git
WORKDIR /grammars/tree-sitter-php/php
RUN tree-sitter generate

# Stage 2: Minimal runtime image
FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    findutils \
    coreutils

# Copy tree-sitter binary
COPY --from=builder /usr/local/cargo/bin/tree-sitter /usr/local/bin/

# Copy PHP grammar
COPY --from=builder /grammars/tree-sitter-php /usr/local/share/tree-sitter/php

# Create working directories
WORKDIR /workspace
RUN mkdir -p /base_sha /head_sha /result

# Setup tree-sitter config to find PHP grammar
RUN mkdir -p /root/.config/tree-sitter && \
    echo '{"parser-directories": ["/usr/local/share/tree-sitter"]}' > /root/.config/tree-sitter/config.json

# Copy scripts
COPY i18n-diff.sh /usr/local/bin/i18n-diff.sh
COPY i18n-php-gettext.scm /usr/local/share/i18n-diff/i18n-php-gettext.scm

# Make script executable and set query file location
RUN chmod +x /usr/local/bin/i18n-diff.sh
ENV QUERY_FILE=/usr/local/share/i18n-diff/i18n-php-gettext.scm

SHELL ["/bin/bash", "-c"]
ENTRYPOINT ["/usr/local/bin/i18n-diff.sh"]
CMD ["-h"]
