# docker/dev.Dockerfile
# Overridable so CI can exercise every supported Ruby (>= 3.1) via a matrix
ARG RUBY_IMAGE=ruby:3.4.8-alpine3.23
FROM ${RUBY_IMAGE}

# Base packages:
# - Runtime: bash (for CI commands), git (bundler-audit update), openssl (runtime lib), tzdata, libstdc++
# - Build deps: build-base, openssl-dev (for native extensions) — removed after bundle install
RUN apk upgrade --no-cache && \
    apk add --no-cache \
      bash \
      git \
      openssl \
      tzdata \
      libstdc++ \
      yaml \
      pkgconf && \
    apk add --no-cache --virtual .build-deps \
      build-base \
      openssl-dev \
      yaml-dev  

WORKDIR /app

# Leverage docker layer caching for gems
COPY verikloak-audience.gemspec ./
RUN mkdir -p lib/verikloak/audience
COPY lib/verikloak/audience/version.rb lib/verikloak/audience/version.rb
COPY Gemfile Gemfile.lock ./

# Faster, more reliable bundler installs
ARG BUNDLE_FROZEN=1
ENV BUNDLE_JOBS=4 BUNDLE_RETRY=3 BUNDLE_FROZEN=$BUNDLE_FROZEN
# Install the exact Bundler version recorded in Gemfile.lock (the line after
# the BUNDLED WITH marker) so older base images resolve the lockfile
# deterministically. Anchored on the marker rather than file position so
# trailing lines can't break the parse. Note: whoever re-locks the file pins
# the Bundler used here, and Bundler 2.7+ drops Ruby 3.1 support.
RUN gem install bundler:"$(awk '/^BUNDLED WITH/ { getline; gsub(/[[:space:]]/, ""); print; exit }' Gemfile.lock)" --no-document && \
    bundle install

# App source
COPY . .

# Run as non-root for safety in CI/dev, and match host UID/GID for bind-mount write access
ARG UID=1000
ARG GID=1000
RUN addgroup -S -g $GID app \
    && adduser -S -u $UID -G app app \
    && chown -R app:app /app \
    && chown -R app:app /usr/local/bundle

USER app
