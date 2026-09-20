# The kit

The kit is a consumer project with the same form as `kubemicrovm-ops` and `fountain-ops`. It lists several chant lexicons, and it holds the Ops that combine them.

## The constraint

`00-principles.md` sets the constraint. knr-ops is an approach, and the kit is an optional route beside it. If you drop chant, your knr-ops still works fine.

The kit is organised in adoption levels, and every level passes the drop test. The first level converts nothing. It has to be useful to a team that never writes TypeScript resource code.

## Adoption levels

### Level 1, beside the YAML

The YAML stays as it is, apart from one label per kustomize root. Gap 3 in `06-gaps-and-open-questions.md` explains that label. Flux remains the reconciler, and chant applies nothing.

| Feature | How it works |
|---|---|
| One build over every overlay | `k8s.kustomize.roots` renders each overlay into a single build |
| Estate-wide checks | Lint and audit run over that build. `mise run validate` proves that each overlay builds, and these checks add whether the overlays agree with each other |
| One graph | `chant graph` draws the management side, the workload side and the AWS account together |
| Queries | `chant search` answers a question about the estate in a few rows |
| Cluster reads | `chant kube` reads any cluster with a verdict per row, under an enforced context binding |
| Scheduled drift reports | `WatchOp` reports drift on a schedule. It covers the AWS resources that ACK and CAPA create, which sit outside Flux's view |
| Lifecycle runs | Bootstrap, pivot and teardown run as Ops. Each phase calls the existing script for that phase |

### Level 2, typed lifecycle steps

The Ops replace their script calls with typed builders, one step at a time. The builders are `kindUp`, `helmInstallPinned`, `ensureSecret`, `kubectlApply`, `waitForReady` and `clusterctlMove`. Each converted step removes one tool from what the Op needs installed.

The YAML is still the source at this level. `knr-bootstrap` stays in the repo and keeps working, since the Ops are a second driver over the same steps.

### Level 3, typed authoring per directory

A team writes new clusters and apps as typed objects. `chant build` emits plain manifests, and the team commits them at the paths Flux already syncs. Flux reads nothing that is absent from Git. Other directories can stay hand-written for as long as the team likes.

The level has two parts, because only the first is strictly 1:1 with the platform spec.

| Part | What it is | What it adds |
|---|---|---|
| 3a | Generated classes, one typed object per manifest. `chant import --kustomize <dir>` writes the starting point | A misspelled field fails to compile, references between objects are checked, and the editor completes the CRD's own schema |
| 3b | Composites such as `CapaEksCluster` and `FluxAppFor` | A new workload cluster becomes one call. The cost is described in `00-principles.md` |

A converted directory is accepted when konflate shows an empty rendered diff. Reverting means deleting the TypeScript and keeping the committed YAML, which also renders an empty diff.

## Layout

```
knr-chant/
  chant.config.ts
  ops/
    bootstrap.op.ts
    pivot.op.ts
    teardown.op.ts
    watch.op.ts
    converge.op.ts
  stewards/                 optional, see 09-fountain-and-ci.md
  src/                      level 3 only, and empty before that
  params.ts                 a typed reader over ../bootstrap.toml
  justfile
  SKILL.md                  a capability map for agents
  docs/
  design/                   these files
```

The existing kits are standalone repos that own their estate. A knr-ops user already has an estate, so a directory added to their fork may suit them better. The config below assumes that form, with roots pointing at `../mgmt` and `../workload`. The choice is a question for the knr-ops author in `06-gaps-and-open-questions.md`.

## chant.config.ts

```ts
import type { ChantConfig } from "@intentius/chant/config";
import "@intentius/chant-lexicon-k8s";

export default {
  lexicons: ["k8s", "helm", "kind", "zarf", "aws", "github"],
  sourceDir: "src",
  ownership: { stack: "knr-ops", env: { param: "env" } },
  environments: ["local-host", "aws"],
  k8s: {
    kustomize: {
      roots: {
        "mgmt-aws": "../mgmt/aws",
        "mgmt-local-host": "../mgmt/local-host",
        "workload-eu-north-01": "../workload/eu-north-01",
        "workload-eu-west-01": "../workload/eu-west-01",
        "workload-local-host": "../workload/local-host",
      },
    },
    profiles: {
      "local-host": { context: "kind-mgmt" },
      aws: { context: "knr-ops-mgmt" },
    },
  },
} satisfies ChantConfig;
```

This block is a sketch. The real form of `k8s.kustomize.roots` has not been checked against `lexicons/k8s/src/config.ts`.

The sketch raises two design questions. The management context is `kind-mgmt` before the pivot and `knr-ops-mgmt` after it, so one environment pinned to one context is wrong for part of the lifecycle. Two environments per knr environment would solve that, and so would a context that comes from a build parameter.

A knr-ops environment also has three or more clusters, and a profile binds one context. chant observes projects with several stacks one stack at a time, so one stack per cluster is the likely answer. That has not been verified.

## The Ops

### bootstrap

```
Op "bootstrap"
  phase Preflight      tool and engine checks; for aws, the token, age key and quotas
  phase Kind           kindUp("mgmt"); for local-host, start the registry
  phase FluxOperator   helmInstallPinned(flux-operator, version from bootstrap.toml)
  phase Secrets        aws: ensureSecret(flux-github-pat), ensureSecret(sops-age)
                       local-host: ociPush(mgmt/local-host, workload/local-host)
  phase FluxInstance   kubectlApply(FluxInstance); waitForReady
  phase Converge       wait for the management and workload Kustomization chains
```

`ensureSecret` suits the secrets phase. When the secret is present the step is done, and it never writes over an existing value. The age key and the token come from the operator's machine, so neither value ever appears in source.

The Op needs no `onFailure` phase. kind is disposable, and a rerun is safe.

### pivot

```
Op "pivot"   depends: ["bootstrap"]
  phase AwaitMgmt      waitForReady(Cluster/<mgmt>), timeout from bootstrap.toml
  phase Kubeconfig     export the target kubeconfig
  phase Substrate      helmInstallPinned(cert-manager), helmInstallPinned(capi-operator)
                       kubectlApply(provider CRs); waitForReady
  phase Gate           gate("approve-pivot")
  phase Suspend        suspend Flux in kind
  phase Move           clusterctlMove(kind -> target)
  phase Resume         unpause moved clusters; seed Flux on the target
  phase Verify         target reconciles itself; safety checks
  phase DeleteKind     kindDown("mgmt")
  onFailure            resume Flux in kind; leave kind in place
```

The gate sits before the first step that is awkward to reverse. knr-ops runs the pivot by default, and `gate: "never"` keeps that behaviour where a team wants it.

The `onFailure` phase follows the recovery guidance in knr-ops `docs/operations.md`. kind stays authoritative until the final deletion, so the phase resumes Flux there and stops. It leaves moved CAPI objects untouched.

### teardown

```
Op "teardown"
  phase Discover       find the active controller host (kind or self-managed)
  phase Workloads      delete workload Clusters; wait for CAPA to finish
  phase Gate           gate("approve-aws-sweep"), aws only
  phase Sweep          aws: orphaned resources in both workload regions and the mgmt cluster
  phase Global         aws: IAM roles and users, bucket pattern, clusterawsadm stack
  phase Mgmt           delete the management cluster, or kindDown
  phase Registry       local-host: remove the registry
```

The gate binds to the list that the run has already enumerated, so the approver reads exactly what the sweep would delete.

The aws lexicon's `teardownOwned()` could later replace the name lists in the `[teardown]` section of `bootstrap.toml`. That depends on the AWS resources carrying an ownership tag. ACK and CAPA both let a CR set tags on what it creates, and this has not been checked for each kind.

### watch and converge

A `WatchOp` and a `ConvergeOp` run per environment on a schedule. `09-fountain-and-ci.md` describes who can run that schedule and what the converge rules look like.

## bootstrap.toml stays authoritative

Every value in `bootstrap.toml` is a constant that some Op step reads. The kit reads the file at every level, and `params.ts` is only a typed reader over it.

An earlier draft moved the chart versions into typed constants, so that the Op and the `HelmRelease` would share one declaration. That design fails the drop test, because `knr-bootstrap` reads `bootstrap.toml` and must keep working without chant. It would also need a new Renovate custom manager.

The duplication between `bootstrap.toml` and the `HelmRelease` versions therefore stays. The kit adds a lint check that the two agree, listed in section 4 of `04-k8s-additions.md`. That check gives the same guarantee as the knr-ops validate cross-check, across the whole estate.

A fork at level 3 may still want the versions declared once. The permitted design is typed constants from which `bootstrap.toml` is emitted and committed, so the Rust CLI sees no change.

## What the kit leaves to knr-ops

| Area | Already in knr-ops |
|---|---|
| A path without a cloud account | `local-host` |
| Rendered pull request review | konflate, as a merge gate |
| Dependency updates | Renovate with its own test harness |
| Signed air-gap bundles with SBOMs | The Zarf bundle and its nightly verification |

## The checklist from chant#1099

| Item | Status for this kit |
|---|---|
| Stacks and tiers per role | knr-ops has environments. Tiers may not be wanted |
| Lifecycle Ops beyond apply | bootstrap, pivot, teardown, watch and converge. A backup and restore drill for the RDS instances is a candidate |
| Ownership markers | Depends on gap 3 |
| Naming for coexisting instances | knr-ops uses `namePrefix` and a `knr-ops-` prefix on AWS names |
| Generated CI across forges | Covered in `09-fountain-and-ci.md` |
| Operable by agents | A `SKILL.md` and chant's MCP server. knr-ops already ships an `AGENTS.md` |
| A local path without an account | Inherited from knr-ops |
| Docs site | Later |
| Pinned upstream | The kit pins a knr-ops commit and tests against it |
