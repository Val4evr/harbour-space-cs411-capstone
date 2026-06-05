# CS411 Capstone — Node.js build & deployment pipeline

Express service (exam spec: `index.js`, port 4444) built and deployed by a single
GitHub Actions pipeline to three machines in the iximiuz lab: **target** (systemd),
**docker** (container from a registry), and **kubernetes** (k3s).

## Architecture

```
git push to main
  └─ test-and-build   (GitHub-hosted runner)
       npm ci → npm test (node:test) → docker build → smoke-test → push to ttl.sh
            │
            ▼  ttl.sh (anonymous registry — the rendezvous; no side talks to the other directly)
            │
  ┌─ deploy-target      (self-hosted runner)  scp source → node under systemd
  ├─ deploy-docker      (self-hosted runner)  ssh → docker pull + run -p 4444:4444
  └─ deploy-kubernetes  (self-hosted runner)  kubectl apply + roll → pod Ready
```

The self-hosted runner lives on the lab's `kubernetes` machine. It only makes
*outbound* long-poll connections to GitHub, which is why CI can drive machines
behind the playground NAT that GitHub's own runners could never reach.

## Repo layout

| Path | Purpose |
|---|---|
| `index.js` / `index.test.js` | App + unit test (exam-provided code, verbatim) |
| `Dockerfile` | `node:24-alpine` (digest-pinned), non-root, HEALTHCHECK |
| `.github/workflows/ci.yml` | The whole pipeline (4 jobs) |
| `k8s/deployment.yaml` | Deployment (1 replica, Recreate, liveness+readiness, hostPort 4444) |
| `k8s/service.yaml` | NodePort service (30444 → 4444) |
| `k8s/pod.yaml` | Bare pod literally named `myapp` (the exam check runs `kubectl get pod myapp`) |

## Running the pipeline

1. **One-time:** register a self-hosted runner on the lab's `kubernetes` box
   (Repo → Settings → Actions → Runners → New self-hosted runner; install it as a
   service with `sudo ./svc.sh install laborant && sudo ./svc.sh start` so it
   survives SSH sessions). The runner needs: `kubectl` + kubeconfig (k3s default),
   and SSH access to `target` and `docker` as `laborant`.
2. Push to `main` (or trigger manually: Actions → ci → Run workflow).
3. Watch: Actions tab, or `gh run watch --repo Val4evr/harbour-space-cs411-capstone`.

Note: the lab playground is ephemeral — when the VM expires the runner shows
*offline* and deploy jobs will queue. Re-register the runner on a fresh playground
to bring the deploy half back; the build half always works.

## Verifying the deployment

From any machine in the lab network:

```bash
curl http://target:4444/      # systemd:    {"name":"Hello","description":"World","url":"target:4444"}
curl http://docker:4444/      # container:  same JSON
curl http://kubernetes:4444/  # k8s hostPort: same JSON
curl http://kubernetes:30444/ # k8s through the NodePort Service
```

On the kubernetes box: `kubectl get pod myapp` → `Running`, and
`kubectl get deploy myapp` → `1/1` ready.

Unit tests run in CI (`Unit test stage`), or locally with `npm ci && npm test`.

## Image naming

Each commit is pushed as `ttl.sh/val4evr-capstone-<sha>:24h` (unique name per
build → Kubernetes rollouts are unambiguous, no stale-cache reuse) and also as
the fixed alias `ttl.sh/val4evr-myapp:24h` used by the bare `myapp` pod
(`imagePullPolicy: Always`). ttl.sh is anonymous and transient: the tag *is* the
TTL — images vanish 24 h after the last push, so re-run the pipeline if pulls
start 404ing.
