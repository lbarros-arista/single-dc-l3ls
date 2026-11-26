# Node.js 24 LTS runtime and npm (matches the target build architecture).
FROM node:24-bookworm-slim AS node-runtime

# Use the Arista AVD image as the base
FROM ghcr.io/aristanetworks/avd/universal:python3.14-avd-v6.5.0

# 1. Install system dependencies as root
USER root
RUN apt-get update && apt-get install -y \
    acl xz-utils iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 24 and the pinned EOS MCP server at image build time.
COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    npm install --global --ignore-scripts @aristanetworks/eos-mcp-server@0.13.1-beta && \
    npm cache clean --force && \
    node --version && \
    eos-mcp-server --help

# 2. Python Tools
RUN pip3 install --no-cache-dir passlib
RUN pip install --upgrade pip

# 3. Install Containerlab (Creates clab_admins group)
RUN curl -sL https://get.containerlab.dev | bash

# 4. The "Security Sync"
# We explicitly add the user to the groups AFTER install.
# We also create 'docker' group just in case it's missing in the base image.
RUN groupadd -f docker && \
    usermod -aG docker,clab_admins avd && \
    echo "avd ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/avd

# Set the default user back to avd (or change to ansible if you prefer)
USER avd
