FROM ubuntu:22.04 AS toolchain

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git pkg-config libssl-dev unzip \
    && rm -rf /var/lib/apt/lists/*

ENV CARGO_HOME=/opt/cargo RUSTUP_HOME=/opt/rustup
ENV PATH=/opt/cargo/bin:${PATH}
WORKDIR /opt/verus
COPY rust-toolchain.toml ./
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh \
    && sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain none \
    && rustup toolchain install \
    && rm /tmp/rustup-init.sh

FROM toolchain AS build
COPY .git .git
COPY source source
COPY dependencies dependencies
COPY tools/common tools/common
WORKDIR /opt/verus/source
ARG BUILD_JOBS=4
ENV CARGO_BUILD_JOBS=${BUILD_JOBS}
ENV VERUS_Z3_PATH=/nonexistent/z3
RUN cargo build --locked --release -p rust_verify -p verus -p cargo-verus \
    && cargo run --locked --release -p cargo-verus -- \
        build --release --manifest-path vstd/Cargo.toml -- --no-verify
RUN mkdir /opt/verus-bin \
    && cp target-verus/release/verus target-verus/release/rust_verify \
        target-verus/release/cargo-verus target-verus/release/libverus_builtin.rlib \
        target-verus/release/libverus_builtin_macros.so \
        target-verus/release/libverus_state_machines_macros.so \
        target-verus/release/libvstd.rlib target-verus/release/vstd.vir /opt/verus-bin/

FROM toolchain AS runtime
ARG Z3_VERSION=4.12.5
ARG Z3_PLATFORM=x64-glibc-2.35
RUN curl --fail --location --show-error \
        "https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/z3-${Z3_VERSION}-${Z3_PLATFORM}.zip" \
        -o /tmp/z3.zip \
    && unzip -j /tmp/z3.zip '*/bin/z3' -d /usr/local/bin \
    && rm /tmp/z3.zip \
    && z3 --version
COPY --from=build /opt/verus-bin /opt/verus-bin
COPY source source
COPY dependencies dependencies
COPY tools/ubuntu-22.04/sample tools/ubuntu-22.04/sample
COPY tools/ubuntu-22.04/test.sh /opt/test-verus.sh
ENV PATH=/opt/verus-bin:${PATH}
ENV VERUS_Z3_PATH=/usr/local/bin/z3
WORKDIR /opt/verus/tools/ubuntu-22.04/sample
CMD ["verus", "--crate-type=lib", "src/lib.rs", "-V", "no-solver-version-check"]
