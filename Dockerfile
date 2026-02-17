# ── Stage 1: Build the Svelte frontend ──────────────────────────
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npx vite build

# ── Stage 2: Frontend target (nginx serves static files) ───────
FROM nginx:alpine AS frontend

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# ── Stage 3: Backend target (Express API only) ─────────────────
FROM node:20-alpine AS backend

WORKDIR /app

# Install only production deps + tsx (needed to run TypeScript server)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm install tsx

# Copy server source (tsx runs TypeScript directly)
COPY server ./server

# Persistent data directory for saved JSON files
RUN mkdir -p /app/server/data
VOLUME ["/app/server/data"]

ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

CMD ["npx", "tsx", "server/index.ts"]
