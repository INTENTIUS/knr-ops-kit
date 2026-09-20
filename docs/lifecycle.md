# Bootstrap, pivot and teardown

Every declarative change to your estate is a Git commit. A bootstrap or a teardown is different, because it runs once from someone's machine and leaves nothing behind to read. The kit runs the same steps as chant Ops, so each run has named phases and a record. Destructive steps also get an approval.

`knr-bootstrap` still works and still reads `bootstrap.toml`. The Ops read the same file and perform the same steps in the same order. Use whichever suits the moment.

## Bootstrap

```sh
cd kit
npx chant run bootstrap --env local-host-bootstrap
```

```
[phase] Preflight
  ✓ tools(kind, helm, clusterctl)          0.4s
[phase] Kind
  ✓ kindUp(mgmt)                           38s
  ✓ registry(knr-registry)                 2.1s
[phase] FluxOperator
  ✓ helmInstallPinned(flux-operator 0.58.0) 21s
[phase] Secrets
  ✓ ociPush(mgmt/local-host, workload/local-host)  3.0s
[phase] FluxInstance
  ✓ kubectlApply(FluxInstance/flux)        1.2s
  ✓ waitForReady(FluxInstance/flux)        44s
[phase] Converge
  ✓ fluxReconcile(mgmt chain)              6m12s
  ✓ fluxReconcile(workload chain)          3m40s
Op "bootstrap" succeeded after 11m42s
```

| Phase | What it does |
|---|---|
| Preflight | Checks the tools and the container engine. For `aws` it also checks the GitHub token, the age key and the service quotas |
| Kind | Creates or reuses the `mgmt` kind instance. For `local-host` it starts the registry |
| FluxOperator | Installs the chart at the version in `bootstrap.toml` |
| Secrets | For `aws`, ensures `flux-github-pat` and `sops-age` exist. A secret that is already present is left alone. For `local-host`, pushes the OCI artifact |
| FluxInstance | Applies the `FluxInstance` and waits for it |
| Converge | Waits for both Flux chains, and stops early if a `Kustomization` stalls |

The age key and the token are read from your machine when the step runs. Neither value ever appears in the repo or in the run record.

A failed bootstrap needs no cleanup. kind is disposable, and every step is safe to run again.

## Pivot

```sh
npx chant run pivot --env aws-bootstrap
```

| Phase | What it does |
|---|---|
| AwaitMgmt | Waits for the CAPI-managed management cluster, up to `mgmt-ready-timeout` |
| Kubeconfig | Exports the target kubeconfig to `.kube/knr-ops-mgmt.yaml` |
| Substrate | Installs cert-manager and the CAPI operator at the versions in `bootstrap.toml`. It then applies the provider CRs |
| Gate | Stops for approval. Off by default for `local-host` |
| Suspend | Suspends Flux in kind |
| Move | Runs `clusterctl move` from kind to the target |
| Resume | Unpauses the moved clusters and seeds Flux on the target |
| Verify | Confirms that the target reconciles itself |
| DeleteKind | Deletes the kind instance |

The gate sits before the first step that is awkward to undo. With the gate on, the run stops there with exit code 3.

```
Op "pivot" is gated on "approve-pivot" after 4m10s
  approve : chant approve pivot approve-pivot
```

Nothing is held open while you decide. Approve it, run the Op again, and it walks through the gate.

```sh
npx chant approve pivot approve-pivot --actor "$USER"
npx chant run pivot --env aws-bootstrap
```

Set `gate: "never"` in `ops/pivot.op.ts` to pivot without stopping, which is what `knr-bootstrap` does.

### When the pivot fails

If any phase after Suspend fails, the Op runs its failure phase. That phase resumes Flux in kind and stops. kind stays authoritative until DeleteKind, so your estate keeps reconciling from where it was. Fix the cause and run the Op again. `clusterctl move` can run again safely.

Leave moved CAPI objects alone during recovery. Deleting one by hand tells CAPA to delete the real cluster.

## Teardown

```sh
npx chant run teardown --env aws
```

| Phase | What it does |
|---|---|
| Discover | Finds the active controller host, which is kind or the self-managed cluster |
| Workloads | Deletes the workload `Cluster` objects and waits for CAPA to finish |
| Gate | Stops for approval, for `aws` only |
| Sweep | Deletes orphaned AWS resources in both workload regions and the management cluster |
| Global | Deletes the IAM roles and users, the buckets and the `clusterawsadm` stack |
| Mgmt | Deletes the management cluster, or the kind instance |
| Registry | For `local-host`, removes the registry |

The gate is bound to a plan. Before it stops, the run lists every resource that Sweep and Global would delete, and it records a digest of that list. Your approval covers that exact list. If the list has changed by the time you run again, the Op stops again and shows you both digests.

```
Op "teardown" is gated on "approve-aws-sweep"
  would delete 14 resources in eu-north-1, 11 in eu-west-1, 7 global
  plan    : sha256:9f2c...  (chant run log teardown --plan)
  approve : chant approve teardown approve-aws-sweep
```

## Reading runs back

```sh
npx chant run list              # every Op and the state of its latest run
npx chant run status pivot      # the latest run, phase by phase
npx chant run log teardown      # every run, newest first, with who approved what
```

Run records and approvals live on the `chant/lifecycle` branch of your fork. They are history. Deleting the branch changes nothing in a cluster.

## Which driver to use

| Situation | Use |
|---|---|
| You want the upstream behaviour exactly, or the kit is absent | `mise run bootstrap`, `pivot`, `teardown` |
| You want a record, a gate, or a run from CI | `chant run` |
| A teammate needs to see how far last night's run got | `chant run status` |

Both drivers are safe on the same estate, because every step checks what exists before it acts.
