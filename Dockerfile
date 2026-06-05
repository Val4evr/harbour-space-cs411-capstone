# CS411 capstone image. Carries over two habits from the Go-era challenges:
# digest-pinned base (tags are mutable; the digest is content-addressed) and a
# HEALTHCHECK. What had to change for Node: there is no static binary — the
# runtime ships inside the image — so the base is node:22-alpine rather than
# scratch, and the app is COPY'd source, not a compiled artifact.
FROM node:22-alpine@sha256:968df39aedcea65eeb078fb336ed7191baf48f972b4479711397108be0966920

WORKDIR /app

# No npm dependencies (plain node:http), so no package install step / lockfile —
# COPY the source and run it directly.
COPY package.json server.js ./

# Run as the unprivileged user the node image ships with (ch2's non-root lesson).
USER node

EXPOSE 4444

# Container-level liveness: wget ships with alpine's busybox.
HEALTHCHECK --interval=10s --timeout=2s CMD wget -qO- http://localhost:4444/health || exit 1

CMD ["node", "server.js"]
