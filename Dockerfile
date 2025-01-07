# Use a specific Node.js version for better reproducibility
FROM node:23.3.0-slim AS builder

# Fix potential dpkg issues and install dependencies
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends git python3 make g++ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm@9.4.0

# Set Python 3 as the default python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Set the working directory
WORKDIR /app

# Copy package.json and other configuration files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc turbo.json entrypoint.sh ./

# Copy the rest of the application code
COPY agent ./agent
COPY packages ./packages
COPY scripts ./scripts
COPY characters ./characters

# Install dependencies and build the project
RUN pnpm install \
    && pnpm build-docker \
    && pnpm prune --prod

# Create a new stage for the final image
FROM node:23.3.0-slim

# Fix potential dpkg issues and install runtime dependencies
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends git python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm@9.4.0

WORKDIR /app

# Copy built artifacts and production dependencies from the builder stage
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-workspace.yaml ./
COPY --from=builder /app/.npmrc ./
COPY --from=builder /app/turbo.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/agent ./agent
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/characters ./characters
COPY --from=builder /app/entrypoint.sh ./
# COPY --from=builder /app/.env ./

# Set the command to run the application
ENTRYPOINT [ "bash", "entrypoint.sh" ]