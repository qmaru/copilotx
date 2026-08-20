FROM rust:1-trixie AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        musl-tools \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        git \
        pkg-config \
        upx-ucl \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH

RUN case "${TARGETARCH}" in \
    amd64) rustup target add x86_64-unknown-linux-musl ;; \
    arm64) rustup target add aarch64-unknown-linux-musl ;; \
    *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac

ARG REPOSITORY=https://github.com/messense/copilot-api-proxy.git
ARG REF=main

COPY patchs/github-token-path.patch /tmp/github-token-path.patch

RUN git clone --depth 1 --branch "${REF}" "${REPOSITORY}" /src \
    && git -C /src apply /tmp/github-token-path.patch

WORKDIR /src

RUN case "${TARGETARCH}" in \
    amd64) \
        export CC_x86_64_unknown_linux_musl=musl-gcc \
        && export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc \
        && cargo build --release --target x86_64-unknown-linux-musl \
        && upx --best --lzma target/x86_64-unknown-linux-musl/release/copilot-api-proxy \
        ;; \
    arm64) \
        export CC_aarch64_unknown_linux_musl=musl-gcc \
        && export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc \
        && cargo build --release --target aarch64-unknown-linux-musl \
        ;; \
    *) \
        echo "Unsupported architecture: ${TARGETARCH}" \
        && exit 1 \
        ;; \
    esac

FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=builder /src/target/*-unknown-linux-musl/release/copilot-api-proxy /copilot-api-proxy

ENTRYPOINT ["/copilot-api-proxy"]
