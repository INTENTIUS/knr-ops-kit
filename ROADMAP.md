# Roadmap and open questions

The site under `docs/` is written as finished documentation. Those pages describe the kit as it will work. This file is the other half, and it lists two things. One is every claim in the docs that is not true yet. The other is every decision the docs made on someone else's behalf.

Each entry has to be resolved against the docs. It is resolved when the feature ships and the entry is deleted, or when the docs change to match what was decided. When this file is empty, the docs are true.

Evidence for the "today" column is in `research/08-evidence.md`. The evidence dates from 2026-09-20 and refers to chant commit `9eb8a880` and knr-ops commit `f6b8d34`.

## Status at a glance

Nothing in `kit/` exists yet. This repo holds documentation and research only.

| Area | Docs page | Works today with stock chant | Needs work |
|---|---|---|---|
| Estate checks | `checks.md` | FLUX001 to FLUX003 and the `WK8` audit rules over `k8s.kustomize.roots` | R3, R4 |
| Queries | `search.md` | Queries over TypeScript source, `--explain`, live and snapshot modes | R5, R6, R7 |
| Live reads | `clusters.md` | `chant kube`, context binding, the EKS exec plugin | R8, R9, R10 |
| Lifecycle Ops | `lifecycle.md` | Phases, gates, plan-bound gates, `onFailure`, the run ledger, `helmInstallPinned`, `ensureSecret`, `kubectlApply`, `waitForReady` | R1, R11, R12 |
| Drift watch | `watch.md` | `WatchOp`, `ConvergeOp`, `chant operator --once`, sticky issues | R8, R9, R13 |
| Typed authoring | `typed.md` | Most kinds, `chant import --kustomize`, `chant build` | R2, R14, R15 |
| Agents | `agents.md` | `ConciergeStack`, the MCP server, `chant run --on fountain` | R16, R17 |
| CI | `ci.md` | `generateOpsPipeline`, finding modes, `WorkflowAuditOp`, `BehaviourOp` | R18, R19 |
| Dropping the kit | `leaving.md` | True by construction once the kit exists | R20 |

## Roadmap items

### R1. The kind lexicon

| | |
|---|---|
| Docs that depend on it | `lifecycle.md` (Kind phase), `underneath.md`, `ci.md` (nightly run). |
| Today | chant has no kind lexicon. The k3d lexicon is the model, with `k3dUp`, `k3dDown` and `describeResources`. |
| To do | Build `@intentius/chant-lexicon-kind` with `kindUp`, `kindDown`, `kindLoadImage` and a cluster listing. kind appears to publish no JSON schema, so the config types are hand-written or derived from the Go structs. |
| Where | chant. |

### R2. Missing CRD sources

| | |
|---|---|
| Docs that depend on it | `underneath.md` lists every kind as typed. `typed.md` says the editor completes every kind knr-ops uses. |
| Today | Thirteen kinds have no type, and `research/04-k8s-additions.md` section 1 lists them. |
| To do | Add them to `CRD_SOURCES`. Decide the namespace for `operator.cluster.x-k8s.io`, which would otherwise read `K8s::Operator::*`. |
| Where | chant, Kubernetes lexicon. |

### R3. New Flux, CAPI and knr rules

| | |
|---|---|
| Docs that depend on it | `checks.md` lists seven rules beyond FLUX003. |
| Today | None of the seven exists. WK8505 is proposed in chant's SOPS design doc. The rule ids are placeholders. |
| To do | Write them. FLUX and CAPI rules go in the Kubernetes lexicon. KNR001 and KNR002 read `bootstrap.toml`, so they belong in the kit as project rules. |
| Where | chant and the kit. |

### R4. Kustomize root ingest against a real knr-ops checkout

| | |
|---|---|
| Docs that depend on it | `getting-started.md` says a fresh upstream checkout passes `just check`. |
| Today | `k8s.kustomize.roots` ships. Three behaviours are untested here. kustomize leaves `${AWS_REGION}` as a literal. `*.sops.yaml` resources hold ciphertext. Flux and kustomize both have a kind named `Kustomization`, and knr-ops has 83 documents of it. |
| To do | Run ingest against the pinned commit and fix what breaks. Confirm the real config form of `k8s.kustomize.roots`, which the docs sketch from memory. |
| Where | chant, Kubernetes lexicon. |

### R5. Search over ingested roots

| | |
|---|---|
| Docs that depend on it | All of `search.md`. |
| Today | A declared search reads TypeScript source only (`packages/core/src/cli/handlers/search.ts:317`). `chant graph` merges build roots and search does not, so a YAML estate is invisible to search. |
| To do | Have search reuse the merge that graph performs. |
| Where | chant core. |

### R6. A reference catalog for the Kubernetes lexicon

| | |
|---|---|
| Docs that depend on it | Every arrow query in `search.md`, and the one-graph claim on `index.md`. |
| Today | Four other lexicons declare a `referenceCatalog`. The Kubernetes lexicon has none, so objects read from YAML or from a cluster have no edges. |
| To do | Add a catalog covering the references listed in `research/04-k8s-additions.md` section 5. Label-selector edges may need new catalog support. |
| Where | chant, Kubernetes lexicon. |

### R7. Derived attributes for Flux and CAPI

| | |
|---|---|
| Docs that depend on it | `search.md` documents `reconciledBy`, `clusterRole`, `blocked` and `decrypts`. |
| Today | Derived attributes exist for AWS instances only. |
| To do | Add the four. `reconciledBy` can come from Flux inventory labels. |
| Where | chant, Kubernetes lexicon. |

### R8. Ownership for objects that Flux applies

| | |
|---|---|
| Docs that depend on it | `getting-started.md` step 4, the verdict column in `clusters.md`, and all of `watch.md`. |
| Today | chant stamps its ownership label in its own serializer. Flux applies YAML that chant never serialized, so no live object carries the label. The docs show a kustomize `labels:` block, and the label key in it is a guess. |
| To do | Confirm the real label keys. Decide whether chant should also accept Flux's inventory labels as an ownership source, which would remove the YAML change altogether. |
| Where | chant, Kubernetes lexicon. |

### R9. Drift when `kustomize-controller` is the field manager

| | |
|---|---|
| Docs that depend on it | `clusters.md` ("Seeing the drift") and `watch.md` both show field-level drift naming the last writer. |
| Today | chant derives field-level drift from `managedFields` and its own applies use `chant:<stack>`. Whether it can treat another manager's fields as the declared side was not determined. |
| To do | Read `packages/k8s-client/src/managed-fields.ts` and `lexicons/k8s/src/deep-observe.ts`, then build what is missing. |
| Where | chant, Kubernetes lexicon. |

### R10. Tracing ingested objects, stacks per cluster

| | |
|---|---|
| Docs that depend on it | `clusters.md` shows `chant kube source` resolving through a `namePrefix`, and `--stack` selecting a workload cluster. |
| Today | `source` works for typed declarations. Provenance for an object that came from a kustomize root, through a `namePrefix`, is untested. One stack per cluster is a working guess. |
| To do | Test both, and build provenance for ingested objects if it is absent. |
| Where | chant, Kubernetes lexicon. |

### R11. New lifecycle step builders

| | |
|---|---|
| Docs that depend on it | `lifecycle.md`, and the step table in `underneath.md`. |
| Today | `clusterctlMove`, `ociPush`, `fluxSuspend`, `fluxResume` and a step form of `fluxReconcile` do not exist. |
| To do | Build them in the Kubernetes lexicon. `clusterctlMove` wraps the binary in its first version. |
| Where | chant, Kubernetes lexicon. |

### R12. The kit's Ops

| | |
|---|---|
| Docs that depend on it | `lifecycle.md`, `watch.md`. |
| Today | Not written. The sample output in `lifecycle.md` is illustrative. |
| To do | Write `bootstrap`, `pivot`, `teardown`, `watch` and `converge`. A first version can call the existing scripts per phase, as `kubemicrovm-ops` does. |
| Where | the kit. |

### R13. AWS ownership tags through ACK and CAPA

| | |
|---|---|
| Docs that depend on it | `watch.md` says ACK and CAPA stamp the kit's tag through `spec.tags` and `additionalTags`. The teardown plan in `lifecycle.md` lists resources by that tag. |
| Today | Both controllers support tags. Whether chant's aws marker keys can travel that way, per kind, was not checked. |
| To do | Check per kind. Where a kind cannot carry a tag, teardown falls back to the name lists in `bootstrap.toml`. |
| Where | the kit, with possible aws lexicon work. |

### R14. The `CapaEksCluster` composite

| | |
|---|---|
| Docs that depend on it | `typed.md`. |
| Today | Does not exist. |
| To do | Build it. The per-pool fan-out has to stay inside chant's foldable subset, or every field loses provenance. A `CapaEksPool` composite called once per pool is the likely answer. |
| Where | chant, Kubernetes lexicon. |

### R15. Build output at the paths Flux reads, and the konflate acceptance test

| | |
|---|---|
| Docs that depend on it | `typed.md` says `chant.config.ts` maps each source directory to its output path, and that the kit's tests check for an empty konflate diff per root. |
| Today | Output path mapping per source directory was not checked. chant's own round-trip test only compares resource counts and kinds. |
| To do | Confirm or build the mapping. Write the strict round-trip test against the pinned knr-ops commit. |
| Where | chant core, and the kit. |

### R16. The steward on a stock fountain

| | |
|---|---|
| Docs that depend on it | The steward half of `agents.md`. |
| Today | `runtime: "acp"` is [fountain#1634](https://github.com/BinaryBourbon/fountain/pull/1634), which is not in fountain v0.16.0. An instance rejects a Steward at apply. |
| To do | Wait for the upstream change. |
| Where | fountain. |

### R17. Self-hosted fountain as a knr-ops component

| | |
|---|---|
| Docs that depend on it | `agents.md` ("Where fountain runs") names `kit/cluster/fountain/`. |
| Today | `fountain-ops` builds the manifests. No knr-ops component wraps them. Where fountain's sandboxes run when fountain is self-hosted was not checked. |
| To do | Answer the sandbox question first, then write the component. |
| Where | the kit. |

### R18. The convergence job, and `just pipelines`

| | |
|---|---|
| Docs that depend on it | `ci.md`. |
| Today | `generateOpsPipeline`, `chant lifecycle affected` and the push-to-PR lookup all ship. The Op that joins them does not, and neither do the `just` recipes. |
| To do | Write the Op and the recipes. |
| Where | the kit. |

### R19. Cost rows for CAPA kinds

| | |
|---|---|
| Docs that depend on it | `ci.md` ("Predicted cost on the pull request"). |
| Today | `BehaviourOp` ships. The Kubernetes lexicon almost certainly has no `behaviourKinds` rows for CAPA pool kinds. |
| To do | Add them, or remove the section. |
| Where | chant, Kubernetes lexicon. |

### R20. The drop test as a test

| | |
|---|---|
| Docs that depend on it | `leaving.md` ("Checking for yourself"). |
| Today | Not written. |
| To do | Write `just drop-test`. |
| Where | the kit. |

### R21. The Zarf lexicon

| | |
|---|---|
| Docs that depend on it | One row in `underneath.md`. |
| Today | Does not exist. Zarf publishes `zarf.schema.json`, so there is a spec to generate from. |
| To do | Build it only if its capabilities fit chant's plugin mechanism and the image check works as a post-synth check. Otherwise remove the row. |
| Where | chant. |

### R22. Distribution

| | |
|---|---|
| Docs that depend on it | `index.md` and `getting-started.md` install with `npx degit INTENTIUS/knr-ops-kit/kit kit`. |
| Today | No `kit/` directory and no published repo. |
| To do | Create `kit/`. Decide on degit against a template repo or an `npm create` package. |
| Where | the kit. |

## Questions for the knr-ops author

The docs picked an answer to each of these so that they could read as finished. Each answer is a proposal.

| # | The docs say | The question |
|---|---|---|
| A1 | "No second toolchain" protects the absence of an abstraction (`design.md`) | Does that reading match what you meant? It is the foundation of the kit's place beside knr-ops |
| A2 | The kit lives in `kit/` inside a fork | Would you prefer a separate repo that points at a checkout, so that a fork stays free of Node tooling? |
| A3 | Each kustomize root gains one inert ownership label | Is that acceptable in a fork? R8 may remove the need |
| A4 | The Ops are a second driver beside `knr-bootstrap` | Is a second driver welcome, or should the lifecycle have exactly one entry point? |
| A5 | The pivot gate is off by default for `local-host` and on for `aws` | knr-ops pivots by default. Should the kit's default match that everywhere? |
| A6 | Each environment appears twice, as `aws-bootstrap` and `aws` | Is that how operators think about the two phases, or is one environment with a moving context closer? |
| A7 | The operator CronJob is the default scheduler | It adds a workload to the management cluster. Is that in keeping with the reference repo? |
| A8 | Nothing about `local-talos` | It syncs from GitHub because a physical machine cannot reach the laptop registry. Which kit features need a second look there? |
| A9 | `NOTICE` credits knr-ops and states that the kit is independent | Is the credit worded the way you would want? |

## Open technical questions

| # | Question | Affects |
|---|---|---|
| T1 | Does kind publish a machine-readable schema anywhere? A code search found none | R1 |
| T2 | Is `zarf.schema.json` versioned per release and stable enough to pin? | R21 |
| T3 | Do `clusterctlMove` and `ociPush` belong in the Kubernetes lexicon or in a new `capi` lexicon? The docs assume the first | R11 |
| T4 | Can `clusterctl move` run natively through the typed client, or is wrapping the binary the only practical route? | R11 |
| T5 | Does Zarf's own signing make chant's supply-chain verbs redundant for a Zarf package? | R21 |
| T6 | How does one environment cover a management cluster and several workload clusters? | R10 |
| T7 | What does the knr-ops `renovate-digest-pinning` job cover, and how much does the reference audit overlap with it? | `ci.md` |

## Still to read in knr-ops

The study read `README.md`, `AGENTS.md`, `bootstrap.toml` and `docs/extending.md` in full. It also read the step list in `docs/bootstrap-cli.md`. Eight pages under `docs/` are unread, including `operations.md` and `konflate.md`. Both bear directly on `lifecycle.md` and `ci.md`, so read them before trusting either page.

## Upstream tracking

[INTENTIUS/chant#2490](https://github.com/INTENTIUS/chant/issues/2490) carries the placement question. It predates this file. Four items found later are absent from it, namely R5, R6, R8 and R9. Its "tension" section is superseded by `docs/design.md`.
