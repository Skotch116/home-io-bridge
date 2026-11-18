# syntax=docker/dockerfile:1

# Home.io Bridge (a fork of PlayOnAir) multi-stage image (glibc). Used by Home Assistant OS via GHCR.
# Build args: BUILD_VERSION, BUILD_ARCH (HA: amd64 | aarch64)

ARG BUILD_VERSION=0.4.0
ARG BUILD_ARCH=amd64

# -----------------------------------------------------------------------------
# Builder
# -----------------------------------------------------------------------------
FROM rust:1.88-bookworm AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    libclang-dev \
    pkg-config \
    perl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY Cargo.toml Cargo.lock rustfmt.toml clippy.toml deny.toml ./
COPY crates/play-on-air crates/play-on-air
# Path dep (not a workspace member): hard-stop fork of shairplay — see vendor/shairplay/PLAYONAIR.md.
COPY vendor/shairplay vendor/shairplay

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    cargo build --release -p play-on-air \
    && cp /src/target/release/play-on-air /tmp/play-on-air

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim

ARG BUILD_VERSION
ARG BUILD_ARCH

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    iproute2 \
    jq \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/play-on-air /usr/local/bin/play-on-air
COPY home_io_bridge/run.sh /usr/local/bin/play-on-air-entrypoint
RUN chmod +x /usr/local/bin/play-on-air-entrypoint

# Home Assistant Supervisor labels + OCI metadata.
LABEL org.opencontainers.image.title="Home.io Bridge" \
  org.opencontainers.image.description="Google Cast speakers as AirPlay 2 speakers, in time with your other speakers" \
  org.opencontainers.image.source="https://github.com/Skotch116/home-io-bridge" \
  org.opencontainers.image.url="https://github.com/Skotch116/home-io-bridge" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${BUILD_VERSION}" \
  io.hass.name="Home.io Bridge" \
  io.hass.description="Google Cast speakers as AirPlay 2 speakers, in time with your other speakers" \
  io.hass.type="app" \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.arch="${BUILD_ARCH}"

ENV PLAY_ON_AIR_CONFIG=/config/play-on-air.toml

# Host network is required at runtime (set by HAOS config.yaml host_network).
CMD ["/usr/local/bin/play-on-air-entrypoint"]
