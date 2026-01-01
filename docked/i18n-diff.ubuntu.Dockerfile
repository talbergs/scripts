FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash findutils coreutils git ca-certificates build-essential python3 nodejs npm && \
    npm install -g tree-sitter-cli && \
    git clone --depth 1 https://github.com/tree-sitter/tree-sitter-php.git /grammars/tree-sitter-php && \
    cd /grammars/tree-sitter-php/php && tree-sitter generate && \
    mkdir -p /root/.config/tree-sitter && \
    echo '{"parser-directories": ["/grammars"]}' > /root/.config/tree-sitter/config.json && \
    # Pre-compile the PHP grammar so we can remove build-essential
    mkdir -p /root/.cache/tree-sitter/lib && \
    cd /grammars/tree-sitter-php/php && \
    cc -O2 -fPIC -shared -std=c11 -I src src/parser.c src/scanner.c -o /root/.cache/tree-sitter/lib/php.so && \
    apt-get purge -y git build-essential python3 && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /root/.npm

RUN mkdir -p /base_sha /head_sha /result
WORKDIR /result

COPY i18n-diff.sh /usr/local/bin/
COPY i18n-php-gettext.scm /usr/local/share/i18n-diff/
RUN chmod +x /usr/local/bin/i18n-diff.sh

ENV QUERY_FILE=/usr/local/share/i18n-diff/i18n-php-gettext.scm
SHELL ["/bin/bash", "-c"]
ENTRYPOINT ["/usr/local/bin/i18n-diff.sh"]
CMD ["-h"]
