# Gaps in chant, and open questions

## Gaps

Reading chant's code at the studied revision turned up four gaps. Each one affects the first adoption level. None of them is recorded on chant#2490 yet.

### Gap 1. A search over declared source skips ingested YAML

`chant search` without `--live` builds its graph from the TypeScript source alone.

```
packages/core/src/cli/handlers/search.ts:317
    const discovered = await discover(resolve(args.src ?? config.sourceDir ?? "."));
    ir = buildGraphIr(discovered.entities);
```

`chant graph` merges the entities that lexicons contribute through `buildRoots()`.

```
packages/core/src/cli/handlers/graph.ts:242   collectBuildRootContributors(...)
packages/core/src/cli/handlers/graph.ts:428   mergeGraphBuildRoots(declared.entities, buildRoots)
```

An estate that enters chant through `k8s.kustomize.roots` therefore appears in `chant graph` and is absent from `chant search`. For a team at level 1, that is the whole estate. The live path at `search.ts:275` starts from the same source graph. The variant for projects with several stacks was not read.

The likely fix is for search to reuse the merge that graph performs. It looks small, and it would help terraform roots as well.

### Gap 2. The Kubernetes lexicon has no reference catalog

Four lexicons declare a `referenceCatalog`, and the Kubernetes lexicon is absent from that group. Running `grep -l referenceCatalog lexicons/*/src/plugin.ts` lists four plugins, and `08-evidence.md` names them.

chant builds edges between declared resources by following TypeScript references. Objects parsed from YAML carry no such references, and objects read from a live cluster carry none either. A catalog is how chant rebuilds those edges. Without one, the edge operators in `chant search` have nothing to follow in a YAML estate.

The useful knr-ops queries are all traversals. One example asks for everything downstream of `capa-system`. Another asks for clusters that have no pod identity association. Section 5 of `04-k8s-additions.md` lists the edges a catalog would need.

### Gap 3. Ownership markers never reach objects that Flux applies

A live read observes owned resources. Ownership is a label that chant's serializer stamps at build time, as `lexicons/k8s/src/plugin.ts:41` shows.

At level 1, chant's serializer never writes the files that Flux applies. No live object carries the marker, so chant treats every object as foreign. The verdict column, the drift report and a live search then have nothing to report.

A kustomize `labels:` transformer in each root can stamp the marker keys today. chant's docs say that other tools may stamp labels beside it. This is a small YAML change, and the feature notes describe it as one label per root.

A more complete answer would let chant accept Flux's own inventory labels as an ownership source. The labels `kustomize.toolkit.fluxcd.io/name` and `/namespace` already say which `Kustomization` owns an object. That is a design question for chant.

On the AWS side, ACK and CAPA both let a CR set tags on the resources it creates. Whether chant's aws marker keys can travel that way has not been checked for each kind.

### Gap 4. Drift when another tool manages the fields

chant derives property-level drift from `managedFields`, per field manager. Its own applies use the manager `chant:<stack>`. In a knr-ops cluster the manager is `kustomize-controller`.

The study did not settle whether chant's drift logic can treat another manager's fields as the declared side. If it assumes chant applied the object, deep drift on a Flux estate has nothing to compare against. The relevant code is `packages/k8s-client/src/managed-fields.ts` and `lexicons/k8s/src/deep-observe.ts`.

The identity-depth read should be unaffected. That read reports whether a declared object exists and whether it is Ready.

## Questions for the knr-ops author

These decisions depend on how knr-ops is meant to be used. The design leaves each one open.

1. The design reads "no second toolchain" as a statement about abstractions, as `00-principles.md` explains. The kit's place beside knr-ops depends on whether that reading matches the intent.
2. The kit could be a directory inside a fork, or a separate repo that points at a checkout. A directory keeps everything in one place, and a separate repo keeps the fork free of Node tooling.
3. The live features need one ownership label on each kustomize root. The label is inert without chant. Whether that change is acceptable in the reference repo is the author's call.
4. The Ops are a second driver over the steps that `knr-bootstrap` runs. They read the same `bootstrap.toml`. It would help to know whether a second driver is welcome, or whether the lifecycle should have exactly one entry point.
5. The pivot Op adds an approval gate before `clusterctl move`. knr-ops pivots by default. The default for the kit could follow knr-ops, with the gate as an opt-in.
6. The management context changes identity at the pivot, and chant binds an environment to one context. The cleanest mapping depends on how operators think about the two phases.
7. `local-talos` syncs from GitHub because a physical machine cannot reach the laptop registry. Any kit feature that assumes the OCI path needs another look for that environment.
8. `chant operator` could run as a CronJob on the management cluster. That matches the knr-ops stance that the cluster is the control plane. It also adds a workload to the reference repo.

## Open technical questions

The first eight are carried from chant#2490.

| # | Topic | What is unknown |
|---|---|---|
| 1 | kind schema | kind may publish no schema that a machine can read. A code search found none |
| 2 | Zarf schema | `zarf.schema.json` has to be versioned per release to be pinned |
| 3 | Home for CAPI verbs | `clusterctlMove` and the OCI push builder could go in the Kubernetes lexicon or in a new `capi` lexicon. The first answer is the Kubernetes lexicon |
| 4 | Native move | `clusterctl move` might run through the typed client. Wrapping the binary may be the only practical route |
| 5 | CRD sources | The order in which to add the missing sources |
| 6 | `CapaEksCluster` | The composite has to be justified, and its fan-out per pool has to stay traceable |
| 7 | Flux checks | The set of layout checks that belong beside FLUX001 to FLUX003 |
| 8 | Zarf capabilities | Zarf's own signing may make chant's supply-chain verbs redundant for a Zarf package |
| 9 | Flux variables | kustomize leaves `${AWS_REGION}` as a literal, so a check on such a field would see the placeholder |
| 10 | SOPS files | chant keeps ciphertext out of its primary output for typed declarations, and the ingest path may differ |
| 11 | Two kinds named `Kustomization` | knr-ops has 83 documents of that kind across both API groups, and ingest has to keep them apart |
| 12 | Several clusters per environment | One stack per cluster is the working guess |

## Risks

| Risk | Note |
|---|---|
| The kit is heard as a second toolchain | It needs Node and a chant install. The drop test and the 1:1 point have to come first in any description of it |
| The round-trip claim outruns its test | chant's `full-roundtrip` compares resource counts and kinds. The stricter check in `00-principles.md` does not exist yet |
| knr-ops keeps moving | The shell scripts are being ported to Rust, and Talos support is landing in a series. The kit pins a commit and expects its Op phases to change |
| Features are described before they ship | `07-features.md` marks the status of every feature, and that table must stay current |
