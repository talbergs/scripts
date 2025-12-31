FROM node:22-alpine

RUN apk add --no-cache bash findutils coreutils git && \
    npm install -g tree-sitter-cli && \
    git clone --depth 1 https://github.com/tree-sitter/tree-sitter-php.git /grammars/tree-sitter-php && \
    cd /grammars/tree-sitter-php/php && tree-sitter generate && \
    mkdir -p /root/.config/tree-sitter && \
    echo '{"parser-directories": ["/grammars"]}' > /root/.config/tree-sitter/config.json && \
    apk del git && rm -rf /var/cache/apk/* /root/.npm

WORKDIR /workspace
RUN mkdir -p /base_sha /head_sha /result

COPY i18n-diff.sh /usr/local/bin/
COPY i18n-php-gettext.scm /usr/local/share/i18n-diff/
RUN chmod +x /usr/local/bin/i18n-diff.sh

ENV QUERY_FILE=/usr/local/share/i18n-diff/i18n-php-gettext.scm
SHELL ["/bin/bash", "-c"]
ENTRYPOINT ["/usr/local/bin/i18n-diff.sh"]
CMD ["-h"]
