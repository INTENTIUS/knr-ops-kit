# Where knr-ops, kind and Zarf belong in chant

This file records a placement decision for three things. Each one could be a new chant plugin, an addition to the Kubernetes plugin, or a consumer project. chant calls a plugin a lexicon, and `02-chant-model.md` explains the term.

## The test

Five questions decide each case.

| # | Question | Consequence |
|---|---|---|
| 1 | Does it have a spec of its own that `generate` can read | Without one it can only be a verb-centred lexicon like terraform |
| 2 | Is it installed as a CRD | It belongs in `CRD_SOURCES` |
| 3 | Is it a separate binary with its own verbs and file format | It gets a lexicon of its own, as helm and k3d did |
| 4 | Would its verbs have more than one consumer | If they would not, chant's capability rules exclude it as a home for verbs |
| 5 | Does it need several lexicons at once | It is a consumer project, because a lexicon should stay independent of its peers |

## knr-ops is a consumer project

knr-ops has no spec of its own, so question 1 rules out a lexicon with generated types. Its content is CRDs, and most of them are already typed in the Kubernetes lexicon.

A verb-centred lexicon was considered next, on the terraform model. It would hold bootstrap, pivot and teardown. The table walks through those steps and names the lexicon that already owns each verb.

| Step | Owner |
|---|---|
| Create the kind instance | The proposed kind lexicon |
| Install three charts at pinned versions | helm, with `helmInstallPinned` |
| Inject `sops-age` and `flux-github-pat` | Kubernetes lexicon, with `ensureSecret` |
| Apply the `FluxInstance` and wait | Kubernetes lexicon, with `kubectlApply` and `waitForReady` |
| Wait for Flux convergence | Kubernetes lexicon, with `flux-reconcile` |
| Sweep orphaned AWS resources | aws lexicon |
| Run `clusterctl move` | No owner today |
| Push the OCI artifact that Flux syncs from | No owner today |

Both unowned verbs are general operations that any CAPI or Flux estate might run. Question 4 says their home should serve every CAPI or Flux estate, so they belong in the Kubernetes lexicon.

Reading the existing YAML is covered as well. knr-ops roots are kustomize roots, and `k8s.kustomize.roots` already renders those.

The compositions remain. A bootstrap Op needs four lexicons at once, which is the case question 5 describes. The answer is a kit, in the same form as `kubemicrovm-ops` and `fountain-ops`.

The content therefore goes to three places.

| Destination | What goes there |
|---|---|
| Kubernetes lexicon | `clusterctlMove`, an OCI push builder, missing CRD sources, an EKS cluster composite, Flux layout checks and a reference catalog. `04-k8s-additions.md` has the detail |
| New lexicons | kind and Zarf |
| A kit repo | The Ops that combine several lexicons. `05-kit-design.md` has the detail |

## kind gets a lexicon of its own

The kind config uses `apiVersion: kind.x-k8s.io/v1alpha4`. It looks like a manifest, and no API server ever receives it. It carries no `openAPIV3Schema`, so `CRD_SOURCES` cannot read it. kind is a separate binary with its own file format, which satisfies question 3. The existing k3d lexicon is the closest model.

| Part | Proposal |
|---|---|
| Builders | `kindUp`, `kindDown` and `kindLoadImage`. The last one serves the air-gap flow, which loads image tarballs into the node |
| Observation | `describeResources` lists clusters, as the k3d lexicon does |
| Types | A small set for the config, covering `Cluster`, `Node`, `Networking` and mounts |

A GitHub code search of kubernetes-sigs/kind found no published JSON schema. k3d publishes one. If kind has none, its types would be hand-written or derived from the Go structs under `pkg/apis/config/v1alpha4`. The config that knr-ops generates is six lines long, so a small hand-written set would be enough.

Both existing kits list `k3d`. A knr kit would list `kind` for the same reason, and its first Op phase depends on it. kind is therefore the first piece to build.

## Zarf follows the helm model

`ZarfPackageConfig` also looks like a manifest and is never applied. The `zarf` binary has its own verbs for creating and deploying packages, which satisfies question 3.

Question 1 is satisfied too. The project publishes `zarf.schema.json` at its repo root, and the file is about 370 KB. A Zarf lexicon would have generated types and verbs, as the helm lexicon has.

A Zarf package is a signed archive with an SBOM per component. It is verified and deployed later. chant's build archive and its signing and verification capabilities describe the same sequence, so Zarf fits chant's component ring best. The aws lexicon shows how a lexicon contributes capabilities.

| Contribution | Purpose |
|---|---|
| `zarf-package-create` | A build capability |
| `zarf-deploy` | An apply capability. It would carry a `rollback` if `zarf package remove` is a fair inverse |
| `buildRoots()` over `zarf.yaml` | Reads an existing package definition in place, as the terraform lexicon reads HCL |

One cross-lexicon check would be useful. It would confirm that every image and chart version in the package matches what the Kubernetes manifests reference. knr-ops covers this today with `airgap/images.txt` and Python tests.

## Build order

1. The kind lexicon comes first, because it is small and the kit's first phase needs it.
2. The Kubernetes additions follow, each as its own chant issue.
3. The kit comes next at its first adoption level, where its Ops call the existing scripts.
4. Zarf comes last. That work should proceed only if its capabilities fit the existing plugin mechanism and the image check works as a post-synth check.

## Decision criteria recorded in chant#2490

- Work on kind goes ahead if the k3d design transfers without new core work.
- Zarf goes ahead only under the two conditions in step 4.
- knr-ops gets no lexicon, and the Kubernetes additions are filed separately.
- The kit repo opens only if the first adoption level gives knr-ops users something that `mise run validate` and konflate do not already give them.
