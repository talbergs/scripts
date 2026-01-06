FROM ruby:3.2-alpine

RUN apk add --no-cache bash && \
    gem install sass -v 3.4.22 --no-document

WORKDIR /workspace

ENTRYPOINT ["sass"]
CMD ["--help"]
