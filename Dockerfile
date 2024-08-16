FROM debian:latest as builder

WORKDIR /workspace

# Install dependencies using apt
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
    vim \
    build-essential \
    libusb-1.0-0-dev \
    libssl-dev \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Install Go from the official golang image
COPY --from=golang:1.22.6 /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

# Install web3 cli
RUN curl -LSs https://raw.githubusercontent.com/gochain/web3/master/install.sh | sh

# Install Rust and Foundry
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="/root/.foundry/bin:${PATH}"
RUN foundryup

# RUN git clone --recursive https://github.com/ethereum-optimism/optimism.git && \
#     cd optimism && \
#     git submodule update && \
#     git checkout develop && \
#     git pull origin develop && \
#     git fetch --all && \
#     cd op-node && \
#     make

RUN git clone --recursive https://github.com/barnabasbusa/optimism.git && \
    cd optimism && \
    git submodule update && \
    git checkout getting-started-update && \
    git pull origin getting-started-update && \
    git fetch --all && \
    cd op-node && \
    make


# Use multi-stage build to keep the final image lean
FROM debian:stable-slim

WORKDIR /workspace

# Install dependencies using apt
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    direnv \
    git \
    bash \
    curl \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local
COPY --from=builder /workspace/optimism /workspace/optimism
COPY --from=builder /root/.foundry /root/.foundry

# Set up environment variables
ENV PATH="/root/.foundry/bin:/usr/local/go/bin:${PATH}"


# Set the working directory and default command
WORKDIR /workspace/optimism
CMD ["bash"]
