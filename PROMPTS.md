
## Transfer story (Go homework → Node capstone)

**Reused from the Go-era flow (pattern level, not verbatim prompts):**
- The image-as-artifact + registry-rendezvous shape from the Docker challenge:
  build and run never talk directly; both sides only do outbound ops against
  ttl.sh. Same anonymous registry, same "tag is the TTL" trick.
- The systemd deploy shape from first-deployment-pipeline: scp → `ssh 'sudo
  bash -s'` heredoc → unit with `Restart=on-failure` → `daemon-reload; enable;
  restart`. The target deploy job is structurally the same script.
- The digest-pinned base image and the "a green pipeline must mean the app
  serves traffic" smoke-gate habit (from the ch2 health-check stretch).

**Re-derived for Node (where Go prompts would have been wrong):**
- No static binary: Go shipped one self-contained ELF to scratch; Node needs its
  runtime in the image (`node:24-alpine`) and `npm ci` from a lockfile, with deps
  installed as a separate Docker layer so code-only changes don't re-install.
- The target machine had no Node at all (Go never needed a runtime there) — the
  deploy job installs nodejs via apt before writing the systemd unit.
- New deployment runtime entirely: Kubernetes. The mapping I worked from:
  systemd unit → Deployment, `Restart=on-failure` → restartPolicy + livenessProbe,
  `-p 4444:4444` → Service/hostPort, "is it actually serving" → readinessProbe.

## One specific prompt (of several)

> "I want the pipeline to cover the deployment step as well. I push to main, it
> gets deployed. Let's do a self-hosted runner maybe since this was covered in
> the lecture. Or if there are problems putting the runner on the iximiuz VM we
> can use ssh?"

This was the architectural fork. The agent confirmed a self-hosted runner works
behind the playground NAT (the runner only makes outbound long-poll connections
to GitHub — nothing needs to reach in), registered it on the kubernetes box, and
installed it as a systemd service so it survives SSH session teardown — the
challenge-2 supervision lesson applied to the CI infrastructure itself.

## Friction moments (pick/trim — all real)

1. **Stale-image trap:** first k8s deploy served the OLD app. Fixed tag
   (`:24h`) + `imagePullPolicy: IfNotPresent` + `rollout restart` = kubelet said
   "image already present" and reused yesterday's bytes. Fix: per-commit image
   *names* (`val4evr-capstone-<sha>`), so every deploy is an unambiguous image
   change. Uniqueness belongs in the reference, not in cache policy.
2. **hostPort vs RollingUpdate deadlock:** with `hostPort: 4444`, the default
   rolling update can't ever schedule the new pod (old pod owns the port) —
   switched the Deployment to `strategy: Recreate`.
3. **The check that wouldn't go green:** the dashboard sat on "Waiting for myapp
   pod to run" through three plausible fixes (renamed the Deployment to `myapp`;
   wired kubeconfigs for laborant and root on the jenkins box — both red
   herrings). What settled it: reading the examiner's journal on the kubernetes
   box, which logs the literal probe — `kubectl get pod myapp` — a pod with that
   *exact name*, which a Deployment can never produce (its pods get hash
   suffixes). Added a bare Pod manifest named `myapp`. Lesson: when a checker
   stays red against working infra, stop guessing and trace what the checker
   actually executes.

## One verification step (of several)

After the pipeline went green, I didn't trust its own assertions: from the
playground's jenkins box (a machine the pipeline never touches) I curled all
three targets — `target:4444`, `docker:4444`, `kubernetes:4444` — and checked
the *lowercase* exam JSON shape came back from each, plus
`kubectl get pod myapp` → `Running` and the examiner journal logging
`task "verify_kubernetes" completed successfully`. The pipeline also verifies
itself: unit test stage, container smoke-test before push, and per-target curl
after each deploy.
