# syntax=docker/dockerfile:1
# phr-web -- Rails front end + Sidekiq worker, backed by MySQL and Redis.
ARG RUBY_VERSION=3.3.6

########## base: runtime layer, shared by build and final ##########
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /app

# default-mysql-client pulls in the libmariadb runtime that mysql2 links
# against, and gives us the mysql/mysqladmin CLIs inside the pod for debugging.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      default-mysql-client \
      procps \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

########## build: compile native gems ##########
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      default-libmysqlclient-dev \
      git \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Gemfile* rather than two COPY lines: a glob that matches nothing is a build
# error, and no Gemfile.lock is committed. This picks one up if you add it.
COPY Gemfile* ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

RUN bundle exec bootsnap precompile app/ lib/ config/ || true

########## final ##########
FROM base

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Run unprivileged. Keeps the workload compatible with restrictive Pod
# Security Standards on the cluster.
RUN groupadd --system --gid 1000 rails && \
    useradd --system --uid 1000 --gid 1000 --create-home --shell /bin/bash rails && \
    mkdir -p log tmp/pids && \
    chown -R rails:rails /app
USER 1000:1000

EXPOSE 3000

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
