# Adopt it in levels

You take the kit in steps, and you can stop at any of them. Every level passes the same test. If you drop the kit, your knr-ops still works.

| Level | You change | Flux sees | You get |
|---|---|---|---|
| 1. Beside the YAML | One label per kustomize root | Nothing new | Checks, queries, live reads, drift reports, recorded lifecycle runs |
| 2. Typed lifecycle steps | Nothing further | Nothing new | Lifecycle Ops that need fewer tools installed, and CI runs of the lifecycle |
| 3a. Typed classes | The directories you choose become TypeScript. The built YAML is committed where it was | The same YAML | Type checking, real references, editor completion |
| 3b. Composites | New clusters become one call | The same YAML | The seven-step cluster procedure as one declaration |

## Level 1, beside the YAML

Your YAML stays as it is. The kit reads every kustomize root into one build through `k8s.kustomize.roots` and works on that.

| Feature | What happens |
|---|---|
| One build over every overlay | Each root renders the way `kustomize build` renders it, and the results are joined |
| Estate checks | `just check` lints and audits the joined result, so a reference from one overlay to another is checked |
| One graph | `npx chant graph` draws the management cluster, the workload clusters and the AWS account together |
| Queries | `npx chant search` answers a question in a few rows |
| Cluster reads | `npx chant kube get` adds a verdict to every row and refuses the wrong context |
| Drift reports | A scheduled read covers Kubernetes objects and the AWS resources that ACK and CAPA created |
| Lifecycle runs | `npx chant run bootstrap` and its siblings give each run a record and an approval step |

At this level each lifecycle phase calls the script knr-ops already ships. The Op supplies the phases, the gate and the record. `bootstrap.sh`, `pivot.sh` and `teardown.sh` still do the work.

Most teams stay here.

## Level 2, typed lifecycle steps

The Ops stop calling the shell scripts and use typed steps.

| Script step | Typed step |
|---|---|
| `kind create cluster` | `kindUp` |
| `helm upgrade --install` at a pinned version | `helmInstallPinned` |
| `kubectl create secret` when the secret is absent | `ensureSecret` |
| `kubectl apply` and `kubectl wait` | `kubectlApply` and `waitForReady` |
| `flux suspend` and `flux resume` | `fluxSuspend` and `fluxResume` |
| `flux push artifact` | `ociPush` |
| `clusterctl move` | `clusterctlMove` |

Each converted step takes one tool off the machine that runs the Op. `kubectlApply` and `waitForReady` call the API directly, so a runner needs no `kubectl` binary. That matters most in CI and on a [steward](agents.md).

You change nothing in your fork to move from level 1 to level 2. Set `KIT_LIFECYCLE=typed` in `kit/.env` and the Ops switch over. `knr-bootstrap` keeps working beside them, because both drivers read `bootstrap.toml` and every step checks what exists before it acts.

## Level 3a, typed classes

You convert a directory with `chant import --kustomize`, and `chant build` writes the YAML back to the same path. [Typed authoring](typed.md) walks through it.

The types are the CRDs' own schemas, so one typed object is one manifest. This level is strictly 1:1 with the platform spec. A conversion is accepted when konflate shows an empty rendered diff.

Convert the directories that change often. `mgmt/aws/clusters/` is the usual first choice, because a wrong field there costs an EKS cluster. Leave the rest as YAML for as long as you like.

## Level 3b, composites

A composite turns one call into several manifests. `CapaEksCluster` emits everything that `docs/extending.md` has you write by hand for a new workload cluster.

This is the one level that steps past 1:1. The output is still plain committed YAML, so it still passes the drop test. The cost shows when the kit traces live drift back to your source, and [Typed authoring](typed.md#what-a-composite-costs-you) explains it.

## Going back down

| From | To | How |
|---|---|---|
| 3b or 3a | 1 | Delete the directory under `kit/src/` and keep the committed YAML. konflate shows no diff |
| 2 | 1 | Remove `KIT_LIFECYCLE=typed` |
| 1 | No kit | Follow [Dropping the kit](leaving.md) |

## What stays the same at every level

| Thing | Status |
|---|---|
| Flux | The only writer to your clusters |
| `knr-bootstrap` | Works, and reads `bootstrap.toml` |
| `bootstrap.toml` | Authoritative for chart versions, names, timeouts and teardown targets |
| `mise run validate` | Still your pre-push check |
| konflate | Still your merge gate |
| Renovate | Still updates your pins. It also updates `kit/package.json` |
| SOPS and age | Unchanged. The kit never decrypts a secret and never sees the age key outside the bootstrap step that injects it |
