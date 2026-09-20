# Features, and why each one exists

This file lists what the kit would offer a team that runs knr-ops. Each feature has a reason and a status. The status column is as important as the feature column, because several features depend on chant work that has not shipped.

Three statements hold for every feature.

1. If you drop chant, your knr-ops still works fine.
2. Flux stays the reconciler, and chant applies nothing to a knr-ops cluster.
3. The YAML stays as it is, apart from one ownership label per kustomize root for the live features.

## Checks over the rendered estate

`mise run validate` proves that each overlay builds. It treats each overlay separately, so a reference from one overlay to another goes unchecked until Flux reconciles it. The kit renders every overlay into one build and runs checks across all of them.

| Check | Why it exists | Status |
|---|---|---|
| A `sourceRef` names a declared source | A wrong name stalls the `Kustomization` and everything that depends on it | Shipped as FLUX002 |
| A `dependsOn` name matches a real `Kustomization` | A wrong name blocks ordering with no error at build time | Shipped as FLUX003 |
| A `GitRepository` pins a ref | The unset default is the `master` branch | Shipped as FLUX001 |
| A SOPS file is reachable only through a `Kustomization` with decryption set | Flux would otherwise apply ciphertext | Proposed as WK8505 |
| Every `flux-ks.yaml` is registered in a parent root | An unregistered file reconciles nothing and reports nothing | Proposed |
| A `HelmRelease` version matches `bootstrap.toml` | Flux adopts the bootstrap installs only when the versions agree | Proposed |

These checks depend on `k8s.kustomize.roots`, which has shipped. Its handling of `substituteFrom` variables and SOPS files still needs testing against knr-ops.

## Queries over the estate

A question about the estate usually means a search across `mgmt/` and `workload/`, followed by joining the results by hand. `chant search` runs the join as one query and prints a few rows.

| Feature | Why it exists | Status |
|---|---|---|
| A query by kind or attribute | It replaces a text search with a search over parsed objects | Shipped for TypeScript source. Gap 1 blocks it for ingested YAML |
| An edge traversal as one term | "Clusters with no pod identity association" becomes a single query | Blocked by gap 2, which is the missing reference catalog |
| A match count with near misses | An empty result from a text search says nothing about what was skipped. `--explain` prints "2 of 6 matched" and names each object that failed | Shipped |
| A query against a live cluster or a snapshot | The same question can be asked of Git, of the cluster, or of last night's record | Shipped, for objects that carry the ownership label |

## Live cluster reads

The table compares a read with `kubectl` and a read with `chant kube`.

| Need | With `kubectl` | With `chant kube` | Status |
|---|---|---|---|
| Read a cluster | `kubectl get` shows what exists | Each row also says whether the object is declared, drifted, runtime or orphan | Shipped, for labelled objects |
| Trace an object | The operator searches the repo for a name that `namePrefix` may have changed | `chant kube source` maps the live object to the file that declared it | Shipped for typed source. Ingested YAML needs testing |
| Pick the cluster | A read goes to whichever context is current, and the management context changes at the pivot | Each environment is pinned to a context, and a mismatch is refused before any read | Shipped. The mapping across the pivot is an open question |
| Authenticate to EKS | `aws eks get-token` runs as an exec plugin | The same plugin is on the client's allowlist, and the token is cached for the session | Shipped |

## Lifecycle runs with a record

Bootstrap, pivot and teardown are the part of knr-ops that runs once, from an operator's machine. A Git commit records every declarative change. A lifecycle run leaves no equivalent record. The kit runs the same steps as Ops so that each run has one.

| Feature | Why it exists | Status |
|---|---|---|
| Named phases with a run history | A teammate can see which phase a run reached and how it ended | Shipped |
| Phases that call the existing scripts | Adoption can start without rewriting anything. `kubemicrovm-ops` began the same way | Shipped |
| An approval gate before the AWS sweep | The approver reads the list the sweep would delete, and the approval binds to that list | Shipped as plan-bound gates |
| An optional gate before `clusterctl move` | The move is the first step that is awkward to reverse | Shipped as gates. The default would follow knr-ops |
| A failure phase for the pivot | It resumes Flux in kind and leaves kind in place, which is what the knr-ops recovery doc advises | Shipped as `onFailure` |
| Typed steps for charts, secrets and waits | Each converted step removes one tool from the runner | Shipped as `helmInstallPinned`, `ensureSecret`, `kubectlApply` and `waitForReady` |
| Typed steps for kind | The first phase of bootstrap creates the kind instance | Needs the kind lexicon |
| A typed step for `clusterctl move` | The pivot is the centre of the lifecycle | Proposed |

`knr-bootstrap` and `bootstrap.toml` are untouched. The Ops are a second driver over the same steps.

## One view of the estate

Flux watches the objects it applies. ACK and CAPA create AWS resources from those objects, and Flux has no view of them. The kit reads both sides and joins them.

| Feature | Why it exists | Status |
|---|---|---|
| One graph across clusters and the AWS account | The dependency chain from a `Cluster` to an IAM role crosses three control planes | Shipped for the graph. Needs the reference catalog for edges between YAML objects |
| Scheduled drift reports | A change made outside Git shows up as a finding on a sticky issue | Shipped as `WatchOp`. Needs the ownership label |
| Undeclared AWS resources named early | Teardown sweeps for orphans at the end. A scheduled read names them while the clusters are up | Shipped in the aws lexicon. Whether ACK and CAPA resources can carry the tag is unchecked |

## Typed authoring, per directory

This feature is optional, and it can be reversed for any directory at any time.

| Feature | Why it exists | Status |
|---|---|---|
| Generated classes, one object per manifest | The types are the CRDs' own schemas, so a misspelled field fails before it reaches a pull request | Shipped for most knr-ops kinds. `04-k8s-additions.md` lists the missing ones |
| Import from existing YAML | `chant import --kustomize <dir>` writes the TypeScript starting point | Shipped |
| An empty konflate diff as the acceptance test | The conversion is proven with the review tool knr-ops already trusts | Proposed as the kit's test |
| A workload cluster as one call | `docs/extending.md` lists seven steps across five directories | Proposed as `CapaEksCluster` |

## Scheduled and hosted operations

`09-fountain-and-ci.md` covers these in full.

| Feature | Why it exists | Status |
|---|---|---|
| `chant operator` as a CronJob | It runs the watch and converge ticks inside the management cluster, with no inbound credentials | Shipped |
| A hosted runner for lifecycle Ops | Day-two operations move from a laptop to a declared machine, and its thread records each run | Blocked upstream by fountain#1634 |
| A review agent without credentials | It reads findings and proposes pull requests against the YAML | Needs a fountain instance and nothing else |
| CI pipelines generated per forge | A fork on GitLab or Forgejo gets the same jobs | Shipped, with differences per forge |

## What stays with knr-ops

| Area | Already in knr-ops |
|---|---|
| A path without a cloud account | `local-host` |
| Rendered pull request review | konflate |
| Dependency updates | Renovate |
| Signed air-gap bundles | Zarf, with a nightly verification |
