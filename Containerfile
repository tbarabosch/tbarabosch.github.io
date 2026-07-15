FROM ruby:3.3-bookworm

ENV BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    GEM_HOME=/bundle \
    PATH=/bundle/bin:$PATH

WORKDIR /workspace
