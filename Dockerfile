# CS411 capstone image — exam spec: Node 24 + Express app (index.js).
# Base pinned by digest (tags are mutable; the digest is content-addressed).
FROM node:24-alpine@sha256:2bdb65ed1dab192432bc31c95f94155ca5ad7fc1392fb7eb7526ab682fa5bf14

WORKDIR /app

# Install deps from the lockfile first so this layer caches across code-only changes.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY index.js ./

# Run as the unprivileged user the node image ships with.
USER node

EXPOSE 4444

# The spec app serves only "/" — probe that (wget ships with alpine busybox).
HEALTHCHECK --interval=10s --timeout=2s CMD wget -qO- http://localhost:4444/ || exit 1

CMD ["node", "index.js"]
