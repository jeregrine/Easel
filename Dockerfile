ARG BUILDER_IMAGE="hexpm/elixir:1.19.4-erlang-28.2-debian-bookworm-20260202-slim"
ARG RUNNER_IMAGE="debian:bookworm-20260202-slim"

FROM ${BUILDER_IMAGE} as builder

RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

# Copy the entire repo — easel is a path dep at ../../
COPY . .

WORKDIR /app/examples/phx_demo

RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile
RUN mix compile
RUN mix assets.deploy
RUN mix release

# Runner
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/examples/phx_demo/_build/${MIX_ENV}/rel/phx_demo ./

USER nobody

ENV PHX_SERVER=true

CMD ["/app/bin/server"]
