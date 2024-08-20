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
    vim \
    build-essential \
    libusb-1.0-0-dev \
    libssl-dev \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


RUN GO_VERSION=$(curl -s https://raw.githubusercontent.com/ethereum-optimism/optimism/develop/versions.json | jq -r '.go') && curl -sL https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz -o go$GO_VERSION.linux-amd64.tar.gz &&  tar -C /usr/local/ -xzvf go$GO_VERSION.linux-amd64.tar.gz && rm go$GO_VERSION.linux-amd64.tar.gz

ENV GOPATH=/go
ENV PATH=/usr/local/go/bin:$GOPATH/bin:$PATH

# Clone the Optimism monorepo and build the `op-node` binary for L2 genesis generation.
RUN git clone https://github.com/ethereum-optimism/optimism.git && \
    cd optimism && \
    git checkout develop && \
    git pull origin develop && \
    cd op-node && \
    make

# Install foundry
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="/root/.foundry/bin:${PATH}"
RUN FOUNDRY_VERSION=$(curl -s https://raw.githubusercontent.com/ethereum-optimism/optimism/develop/versions.json | jq -r '.foundry') && foundryup -v nightly-$FOUNDRY_VERSION

# Build the Optimism contracts
RUN cd optimism/packages/contracts-bedrock && forge build


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
