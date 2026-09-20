# The parts of chant this design uses

This file explains the chant concepts the kit depends on, for a reader who has not used chant. Doc paths are relative to `chant/docs/src/content/docs/` unless they begin with `lexicons/` or `packages/`. The study used the revision tagged `chant-v0.75.1`, and every path below refers to it.

## What chant is

chant is a compiler. It takes TypeScript declarations and writes the target platform's own format, such as Kubernetes manifests or CloudFormation. Everything after that step is optional and layered on top.

| Ring | Layer | What it does |
|---|---|---|
| 0 | Synthesis with `chant build` | Typed TypeScript goes in, and spec-native files come out |
| 1 | Ops | Named, phased workflows over those files |
| 2 | Lifecycle dial | Each environment chooses to observe, reconcile or apply |
| 3 | Components | A release composed from a bounded set of verbs |

The kit uses ring 0 for checks and for optional typed authoring. It uses ring 1 for the lifecycle runs, and ring 2 only in its observe position.

## Lexicons

`lexicon-authoring/overview.mdx` defines a lexicon as a plugin that teaches chant one platform. A lexicon contributes types, a serializer and rules.

Every lexicon must implement four methods named `generate`, `validate`, `coverage` and `package`. All four assume an upstream spec that can be fetched and turned into types. The package name is fixed as `@intentius/chant-lexicon-<name>`.

Several optional members matter for this design.

| Member | Why it matters here |
|---|---|
| `buildRoots()` | Renders roots that are declared in config and are not typed chant source. The Kubernetes lexicon uses it for `k8s.kustomize.roots`, which is how an all-YAML estate enters a build |
| `postSynthChecks()` and `lintRules()` | The home for checks on Flux layout |
| `describeResources()` and `observeResourcesDeep()` | Live reads, at identity depth and at property depth |
| `observeAmbient()` | Finds resources of a managed kind that exist without being declared |
| `teardownOwned()` | Lists what a teardown would delete for one ownership identity |
| `ownershipChannel` | States where the lexicon writes and reads chant's ownership marker |
| `referenceCatalog` | Describes how observed resources refer to each other, so that edges can be rebuilt from live objects |
| `commands()` | Mounts a CLI verb group, which is how `chant kube` exists |
| `opRuntime` | Hosts Op runs for `chant run --on <lexicon>` |

### CRDs go into the Kubernetes lexicon

`lexicon-authoring/crd-sources.mdx` sets a rule. "Anything installed as a CRD belongs in the k8s lexicon, not a lexicon of its own." A new lexicon is justified only for a spec outside Kubernetes.

Third-party CRDs enter through an array named `CRD_SOURCES` in `lexicons/k8s/src/crd/crd-sources.ts`. A source is usually a URL pinned to a release. It can also be a Helm chart, and two further forms read a local file or a live cluster. Versions are pinned in a constant beside each entry. Each kind becomes a type named `K8s::<Namespace>::<Kind>`. The namespace comes from the first segment of the API group, and `lexicons/k8s/src/group-namespace.ts` holds the overrides.

The same page warns about scale. A source should name the kinds a project uses, since a whole provider bundle can hold a thousand kinds.

Rules treat CRD kinds the same way as built-in kinds. Argo CD is the worked example, with `ARGO001` before synthesis and `ARGO003` after it.

### Lexicons that exist mainly for their verbs

| Lexicon | Generated types | What it provides |
|---|---|---|
| terraform | 0, and its serializer does nothing | `buildRoots()` over existing HCL, eight step builders, three Op composites, observation and teardown |
| k3d | 22 | `k3dUp`, `k3dDown` and a cluster listing |
| k3s | 10 | `k3sInstall` and `k3sUninstall` |
| helm | 13 | `helmInstall`, `helmInstallPinned` and a cluster probe |

The terraform README says "there is no upstream spec to fetch". The k3d, k3s and helm lexicons all work close to Kubernetes, and each one is still separate from the Kubernetes lexicon.

The code draws a consistent line. The Kubernetes lexicon owns what passes through the API server. That covers CRD types, `kubectlApply`, `waitForReady`, `ensureSecret` and the waits for Argo and Flux. A separate binary with its own verbs and its own file format gets a lexicon of its own.

## Composites

`guide/composite-resources.mdx` describes a composite as a function that takes props and returns several named resources. A composite suits resources that always appear together, or whose names should come from one prop.

The build records where each emitted property came from. Most values come from a parameter or from a literal fixed by the composite. The remaining ones are direct declarations, or they are marked unknown. `chant lifecycle diff` uses that record when it traces drift back to source. When a drifted field came out of a parameter, chant proposes a one-line edit to it. A drifted field that the composite fixes is refused by name. For that reason, any value an operator might change should be a parameter with a default. A composite whose body contains an `if` or an array transform records every property as unknown.

The Kubernetes lexicon already ships two Flux composites, documented in `lexicons/k8s/docs/pages/flux-composites.mdx`. `FluxGitSource` declares a repository once, and `FluxAppFor` declares one `Kustomization` per app. Three rules come with them.

| Rule | What it catches |
|---|---|
| FLUX001 | A `GitRepository` with no ref pin |
| FLUX002 | A `sourceRef` that names a source nothing declares |
| FLUX003 | A `dependsOn` name with no matching `Kustomization` |

## Ops

`guide/ops.mdx` defines an Op as a named, phased workflow in a `*.op.ts` file. `chant run <name>` runs it in the current process with nothing installed. `--on <lexicon>` hands the same Op to a hosting runtime.

| Feature | Behaviour |
|---|---|
| Phases and steps | Steps run in order by default. A step with an `id` publishes outputs that later steps can read, and the build type-checks those references |
| Gates | A run that reaches an unapproved gate records that it is waiting and exits with code 3. Nothing stays open. `chant approve` records the answer, and the next run reads it. A gate can bind to a plan digest, so an approval covers one specific change set |
| Compensation | `onFailure` phases run in order after an unhandled error. A gate does not count as a failure |
| Dependencies | `depends` names Ops that must succeed first, and the build checks the names |
| Audit | Every run appends a record to a ledger on the `chant/lifecycle` branch |
| Scheduling | `schedule` is data on the Op. A CI generator, `chant operator` or a fountain Steward can each read it |

chant ships several composites built from Ops. `WatchOp` observes, `ReconcileOp` opens pull requests, and `ApplyOp` applies. `BehaviourOp` predicts cost on a pull request, and `WorkflowAuditOp` audits CI references.

## Lifecycle

`concepts/lifecycle-models.mdx` places any tool on three axes.

| Axis | Options | chant's position |
|---|---|---|
| Where truth lives | A state file, the live system, or the source | The live system |
| Reconcile direction | Apply, sync back to code, or observe | Chosen per environment |
| Who answers "is this mine" | A state file, a live marker, or nobody | A live marker on the resource |

knr-ops sits at a different point on the first two axes. Its truth is the source, and Flux applies continuously. chant's Flux documentation already describes that split. chant handles authoring and checks, and Flux reconciles. chant then reads convergence back. In a knr-ops estate `ApplyOp` has no role, and the observe position is the one the kit uses.

One invariant keeps chant's model from turning into a state file. Ownership is read from the live marker and the snapshot is only evidence, so a snapshot can be deleted between runs without changing behaviour.

### The ownership marker

`configuration/config-file.mdx` describes the marker as opt-in. When `ownership.stack` is set, the serializer stamps a label carrying the stack identity onto each resource at build time. The Kubernetes lexicon reads it back during observation. The docs state that other tools may stamp their own labels beside it.

The stamp happens inside chant's serializer. Flux applies knr-ops YAML that chant never serialized, so the marker needs another route into a knr-ops estate. `06-gaps-and-open-questions.md` covers this as gap 3.

## Components and releases

`concepts/components.mdx` defines a component as a releasable unit declared as data in a `*.component.ts` file. A component compiles down to an Op. A composite answers what infrastructure exists, and a component answers how a unit ships.

Components are built from capabilities, which are typed verbs with an optional paired `rollback`.

| Contributor | Capabilities |
|---|---|
| core | Build, SBOM generation, signing and verification, generic waits, `ensure-secret`, `shell` |
| aws lexicon | Publish, CloudFormation and ECS applies, job submission, host delivery, snapshots |
| Kubernetes lexicon | `kubectl-apply`, `kustomize-apply`, `argo-app`, `flux-reconcile` |

Lint enforces a discipline on capabilities. A capability must name an operation and may not name a component. The docs add that a capability used by exactly one component is a warning sign. That rule shapes the placement decision in `03-placement.md`.

## chant search

`cli/search.mdx` describes a query over the estate graph. The graph holds resources and the references between them. The command returns one line per match.

| Term | Matches |
|---|---|
| `word` | A substring of an id, a kind or an attribute value |
| `kind:<substr>` | A node whose kind contains the substring |
| `attr:<name>=<val>` | A node with that attribute value |
| `->kind:X` and `<-kind:X` | A node with an edge to or from a matching node |

The edge operators turn a traversal into one term. `--explain` adds a count such as "4 of 6 matched" and lists the near misses with the term each one failed.

By default the query runs over declared source. `--live --env` runs it over a live environment, and `--at latest` runs it over a recorded snapshot. `--check-live` compares only the matched rows against a fresh read, and `--fail-on-drift` turns that comparison into a CI gate. A live read that fails is reported as a failure. It is never reported as an empty estate.

## chant-k8s-client and chant kube

`@intentius/chant-k8s-client` is the typed API client behind every live cluster feature. It is an optional dependency of the Kubernetes lexicon, and a test keeps it off the build path.

| Property | Detail |
|---|---|
| Coverage | The operation table comes from the same generation pass as the types, including every bundled CRD. The client confirms each address against the cluster's own API discovery |
| Typed failures | A `403` becomes "not observed, no credentials", and a `404` becomes a real absence |
| No `kubectl` binary | `kubectlApply` and `waitForReady` call the API directly |
| Cluster binding | `k8s.profiles.<env>.context` is passed on every request. A mismatch with the current context is refused before any read, and both contexts are named |
| Credential plugins | `aws`, `kubelogin`, `gke-gcloud-auth-plugin` and `kubectl` are allowed by default. Tokens are cached, and the credential path is recorded with the observation |
| managedFields | The client parses field ownership per manager, which is the basis for property-level drift |

`chant kube` is the terminal surface over that client. Its verbs are listed below.

| Verb | Note |
|---|---|
| `get` and `describe` | Work for any kind the cluster serves. Inside a chant project, `get` adds a verdict per row with the values declared, drifted, runtime and orphan |
| `source` | Maps a live object to the file that declared it |
| `apply` and `delete` | Preview by default, and `--yes` makes the change. The kit never uses them against a knr-ops cluster |
| `logs`, `events`, `top`, `wait` | Reads with the same cluster binding |

## The existing kits

Two repos already have the form this design proposes. `kubemicrovm-ops` calls itself "a chant adoption kit", and `fountain-ops` follows the same layout. Each has a `chant.config.ts` that lists several lexicons, an `ops/` directory and a `src/` tree.

`kubemicrovm-ops` lists eight lexicons. Its single Op is a teardown with three phases, and each phase calls an existing shell script. `fountain-ops` lists four lexicons.

chant issues #1098 and #1099 reached the same verdict for Slurm and for Pelican. Both platforms suit a consumer project built on existing lexicons. Issue #1099 also lists what a complete kit includes, and `05-kit-design.md` checks this design against that list.
