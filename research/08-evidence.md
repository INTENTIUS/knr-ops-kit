# Evidence

This file records how each claim in the folder was checked, so that anyone can repeat the check. All checks ran on 2026-09-20 against chant `9eb8a880` and knr-ops `f6b8d34`.

`~/checkouts` is a symlink to `~/Documents/checkouts`, so both paths name the same knr-ops checkout.

## Checked against code or a live source

| Claim | How it was checked | Result |
|---|---|---|
| knr-ops kinds and their counts | A `grep` for `^kind:` across `mgmt`, `workload` and `airgap`, then a count | The table in `01-knr-ops.md` |
| Which knr-ops kinds the Kubernetes lexicon types | A `grep` for each type name in `lexicons/k8s/src/generated/lexicon-k8s.json` | Both tables in `04-k8s-additions.md` |
| The CRD groups in `CRD_SOURCES` | The doc comments in `lexicons/k8s/src/crd/crd-sources.ts` | Twenty-three groups, including CAPI core, CAPA, the CAAPH addon kinds and four ACK controllers |
| chant already refers to knr-ops | A `grep` for `knr-ops` in chant, and `git log --grep=knr` | `flux-app.ts`, the SOPS design doc and commit `d5ba61ed` |
| Lexicons with few resource types | A count of resource entries in each generated registry | terraform has none, and k3s, helm and k3d have 10, 13 and 22 |
| The terraform lexicon centres on verbs | Its README, `src/plugin.ts`, `src/op/builders.ts` and `src/composites/` | A serializer that does nothing, `buildRoots()`, eight builders and three Op composites |
| Builders in the Kubernetes, helm, k3d and k3s lexicons | A `grep` for exported constants in each `src/op/builders.ts` | The names quoted in `02-chant-model.md` |
| chant wraps none of clusterctl, zarf, kind or sops | A `grep` across the Kubernetes, k3d and helm lexicons and core's Op code | No match outside tests |
| The form of the existing kits | `chant.config.ts` and `ops/` in `kubemicrovm-ops` and `fountain-ops` | The lexicon lists quoted in `02-chant-model.md`, and one Op in each |
| The kind config is written inline in three places | A `grep` for `kind.x-k8s.io` in knr-ops | `bootstrap.sh:63`, `bootstrap-rs/src/main.rs:368` and `airgap/scripts/stage-and-create-cluster.sh:46` |
| Zarf publishes a JSON schema | `gh api repos/zarf-dev/zarf/contents/zarf.schema.json --jq .size` | 372946 bytes |
| kind publishes no JSON schema | A GitHub code search of kubernetes-sigs/kind for `schema.json` | No result. A code search is indicative and is not proof |
| A declared search skips `buildRoots` entities | Reading `search.ts` lines 262 to 320 and `graph.ts` lines 242 and 428 | Gap 1 |
| The Kubernetes lexicon has no `referenceCatalog` | `grep -l referenceCatalog lexicons/*/src/plugin.ts` | Four other lexicons matched. Gap 2 |
| Kubernetes ownership is a label stamped by the serializer | `configuration/config-file.mdx` and `lexicons/k8s/src/plugin.ts:41` | Gap 3 |
| The Kubernetes lexicon does not handle Flux's field manager or inventory labels | A `grep` for `kustomize-controller` and `fluxcd.io/name` | No match outside tests. This supports gaps 3 and 4 and leaves gap 4 unsettled |
| `chant import --kustomize` exists | `cli/import.mdx` | It renders a kustomization and imports the result |
| chant states that its output carries nothing specific to chant | `concepts/philosophy.mdx:42` and `concepts/comparison.mdx` | Quoted in `00-principles.md` |
| The pass condition of the Kubernetes round-trip test | `lexicons/k8s/docs/pages/importing-yaml.mdx` | Matching resource counts and kinds |
| chant's conventions for research issues | `gh label list`, an issue search and `gh issue view 1099` | The `research:` title prefix and the `design` label |
| The knr-ops workflows | A `grep` for names, triggers, jobs and actions in `.github/workflows/` | The table in `09-fountain-and-ci.md` |
| fountain's upstream status | The fountain lexicon's `acp`, `resources` and `composites` pages | Issues #1634, #1635 and #1636 are open against v0.16.0 |

## Read from documentation only

The following behaviour was taken from chant's docs and was not compared with code.

- The Op phase grammar and the gate ledger
- The `ConvergeOp` dial matrix and its build-time refusals
- The lease in `chant operator`
- The component and capability model
- The differences between the three CI generators
- The verbs of `chant kube`
- Credential handling in the Kubernetes client
- Observation, import and disruption verdicts in the fountain lexicon

## Not checked

- The real form of `k8s.kustomize.roots` in `lexicons/k8s/src/config.ts`. The config block in `05-kit-design.md` is a sketch.
- How `k8s.kustomize.roots` treats `substituteFrom` variables and `*.sops.yaml` files.
- The separation of the Flux `Kustomization` from the kustomize one during ingest.
- `buildDeclaredPerStack` in `search.ts`, which may merge build roots for projects with several stacks.
- How deep drift treats fields owned by a manager other than `chant:<stack>`.
- The route by which ACK and CAPA CRs could pass chant's aws ownership tags to the resources they create.
- Any `behaviourKinds` rows for CAPA kinds in the Kubernetes lexicon.
- What the knr-ops `renovate-digest-pinning` job covers.
- Where fountain's sandboxes run when fountain is self-hosted on a cluster.

Most knr-ops docs were also left unread. The study read `README.md`, `AGENTS.md`, `bootstrap.toml` and `docs/extending.md` in full. It read the step list in `docs/bootstrap-cli.md` and the head of `airgap/zarf.yaml`. Eight pages under `docs/` are still to read, and the README's documentation table lists them.

## The lint pass

Every file in this folder was linted with `sentences@0.5.1` from npm. The pass called the package's `lintDocument` export with `markdown: true`. Strictness 2 is the package default and the level its thresholds were calibrated against. Strictness 3 reports a pattern on its first appearance.

| File | Score before, at 2 | Score after, at 2 | Score after, at 3 |
|---|---|---|---|
| `README.md` | 12.9 | 2.1 | 2.1 |
| `00-principles.md` | 18.1 | 0 | 0.9 |
| `01-knr-ops.md` | 23.5 | 2.0 | 8.8 |
| `02-chant-model.md` | 35.9 | 3.0 | 10.1 |
| `03-placement.md` | 34.9 | 7.7 | 13.4 |
| `04-k8s-additions.md` | 25.7 | 1.5 | 9.6 |
| `05-kit-design.md` | 9.1 | 1.9 | 6.4 |
| `06-gaps-and-open-questions.md` | 58.8 | 1.6 | 4.8 |
| `07-features.md` | 24.6 | 0.2 | 7.2 |
| `08-evidence.md` | 16.6 | 1.1 | 4.2 |
| `09-fountain-and-ci.md` | 16.7 | 3.4 | 11.5 |

The "before" column for `07-features.md` is the score of the pitch file it replaced. Scores in this table predate the table itself, so a fresh run on this file will differ slightly.

Most findings that remain fall into three groups. The first is a sentence with two clauses and a short list, which the comma-series rule counts as three items. The second is the word "lexicon" recurring in `03-placement.md`, where it is the subject. The third is numbered steps that open with the same verb, where the wording follows the upstream procedure.

## Actions taken outside this folder

One action was taken elsewhere. [INTENTIUS/chant#2490](https://github.com/INTENTIUS/chant/issues/2490) was filed with the labels `design` and `area:k8s`. The four gaps and the later questions were found after filing, so the issue lacks them. Its body also predates `00-principles.md` and still describes typed authoring as a tension with the knr-ops premise.

The chant, knr-ops, `kubemicrovm-ops` and `fountain-ops` checkouts were left unchanged.
