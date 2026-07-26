# -------- 1. BUILD STAGE --------
FROM node:22.12.0-alpine AS builder

WORKDIR /app

# Install ALL dependencies (including dev) to build the app
COPY package*.json ./
RUN npm ci

COPY . .

# Generate Client & Build
RUN npx prisma generate
RUN npm run build

# Remove devDependencies (jest, eslint, etc.) to shrink node_modules
RUN npm prune --omit=dev

# -------- 2. RUNTIME STAGE --------
FROM node:22.12.0-alpine

# Install OpenSSL (Required for Prisma in Alpine)
RUN apk add --no-cache openssl

WORKDIR /app

# 1. The built code
COPY --from=builder /app/dist ./dist
# 2. The production-only node_modules (pruned in previous stage)
COPY --from=builder /app/node_modules ./node_modules
# 3. The schema/migrations (needed for 'prisma migrate deploy')
COPY --from=builder /app/prisma ./prisma
# 4. The package.json (needed for 'npm run' scripts)
COPY --from=builder /app/package.json ./package.json

EXPOSE 4056

# Start the app (Migrations -> Start)
CMD ["npm", "run", "start:prod"]
