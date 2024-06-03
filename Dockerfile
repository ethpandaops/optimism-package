# Stage 1: Builder
FROM debian:latest AS builder

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    jq \
    direnv \
    bash \
    curl \
    gcc \
    g++ \
    python3 \
    python3-pip \
    nodejs \
    npm \
    vim \
    build-essential \
    libusb-1.0-0-dev \
    libssl-dev \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Go from the official golang image
COPY --from=golang:alpine /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

# Install pnpm
RUN npm install -g pnpm@9

# Install web3 cli
RUN curl -LSs https://raw.githubusercontent.com/gochain/web3/master/install.sh | sh

# Install Rust and Foundry
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    cargo install --git https://github.com/foundry-rs/foundry --profile local --locked forge cast chisel anvil

# Ensure Foundry binaries are in PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# Clone the Optimism repository and set up the environment
WORKDIR /workspace
RUN git clone https://github.com/ethereum-optimism/optimism.git && \
    cd optimism && \
    git checkout tutorials/chain && \
    pnpm install && \
    #make op-node op-batcher op-proposer && \
    pnpm build

# Stage 2: Runner
FROM debian:latest

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    jq \
    direnv \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Go from the builder stage
COPY --from=builder /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

# Copy pnpm from the builder stage
COPY --from=builder /usr/local/lib/node_modules/pnpm /usr/local/lib/node_modules/pnpm
COPY --from=builder /usr/local/bin/pnpm /usr/local/bin/pnpm

# Copy web3 cli from the builder stage
COPY --from=builder /usr/local/bin/web3 /usr/local/bin/web3

# Copy Rust and Foundry from the builder stage
COPY --from=builder /root/.cargo /root/.cargo
ENV PATH="/root/.cargo/bin:${PATH}"

# Copy the built application from the builder stage
COPY --from=builder /workspace/optimism /workspace/optimism

# Set the working directory
WORKDIR /workspace/optimism

# Verify installed versions
RUN git --version && \
    go version && \
    node --version && \
    pnpm --version && \
    forge --version && \
    cast --version && \
    make --version && \
    jq --version && \
    direnv --version

# Default command
CMD ["bash"]
