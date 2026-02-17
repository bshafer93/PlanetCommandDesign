# ── Stage 1: Build the Svelte frontend ──────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npx vite build

# ── Stage 2: Production runtime ─────────────────────────────────
FROM node:20-alpine AS runtime

WORKDIR /app

# Install only production deps + tsx (needed to run TypeScript server)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm install tsx

# Copy built frontend
COPY --from=builder /app/dist ./dist

# Copy server source (tsx runs TypeScript directly)
COPY server ./server

# Persistent data directory for saved JSON files
RUN mkdir -p /app/server/data
VOLUME ["/app/server/data"]

ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

CMD ["npx", "tsx", "server/index.ts"]
