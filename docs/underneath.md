# What the kit is built on

The kit is a chant project. chant is a compiler with optional layers on top, and each platform it knows comes from a plugin called a lexicon. You do not need any of this to use the kit. It is here for the day you want to know where a command comes from.

## The lexicons

| Lexicon | What the kit uses it for |
|---|---|
| `k8s` | Reads your kustomize roots, types every kind you use, runs the Flux and CAPI rules, and reads live clusters |
| `helm` | Installs the three charts that bootstrap needs before Flux exists, at the versions in `bootstrap.toml` |
| `kind` | Creates and deletes the `mgmt` kind instance, and loads images into it for the air-gap flow |
| `aws` | Lists the AWS resources that ACK and CAPA created, for drift reports and the teardown sweep |
| `zarf` | Reads `airgap/zarf.yaml` and checks its images and chart versions against your manifests |
| `github` | Generates the workflow files. `gitlab` and `forgejo` do the same for forks on those forges |
| `fountain` | Declares the steward and the review agent. Only needed for [that page](agents.md) |

## Kinds the kit understands

Every kind in upstream knr-ops is typed, which is what lets each feature of the kit see it.

| Family | Kinds |
|---|---|
| Flux | `Kustomization`, `HelmRelease`, `GitRepository`, `OCIRepository`, `HelmRepository`, `FluxInstance` |
| CAPI core | `Cluster`, `MachinePool`, `ClusterClass` |
| CAPI operator | `CoreProvider`, `InfrastructureProvider`, `BootstrapProvider`, `ControlPlaneProvider`, `AddonProvider` |
| CAPA | `AWSManagedControlPlane`, `AWSManagedCluster`, `AWSManagedMachinePool`, `AWSClusterControllerIdentity` |
| CAPD and kubeadm | `DevClusterTemplate`, `DevMachineTemplate`, `KubeadmControlPlaneTemplate`, `KubeadmConfigTemplate` |
| Talos and Tinkerbell | `TalosControlPlane`, `TinkerbellCluster`, `TinkerbellMachineTemplate` |
| CAPI addons | `HelmChartProxy`, `ClusterResourceSet` |
| ACK | `Bucket`, `DBInstance`, IAM `Role` and `User`, `PodIdentityAssociation` |
| cert-manager | `Certificate`, `Issuer`, `ClusterIssuer` |

A provider you add yourself is one entry in the `k8s` lexicon's CRD source list. After that the kit types it like the rest.

## Two files that only look like manifests

The kind cluster config and `airgap/zarf.yaml` both carry an `apiVersion` and a `kind`, and no API server ever receives either. They have their own lexicons for that reason. The `k8s` lexicon handles only what goes through an API server.

## Steps the lifecycle Ops use

| Step | From | Does |
|---|---|---|
| `kindUp`, `kindDown`, `kindLoadImage` | `kind` | Manages the bootstrap instance |
| `helmInstallPinned` | `helm` | Installs a chart at an exact version |
| `ensureSecret` | `k8s` | Creates a secret only when it is absent, and never overwrites one |
| `kubectlApply`, `waitForReady` | `k8s` | Applies and waits through the API, with no `kubectl` binary |
| `fluxSuspend`, `fluxResume` | `k8s` | Patches a `Kustomization` or a `FluxInstance` |
| `fluxReconcile` | `k8s` | Waits for Ready, and stops early when Flux reports a stall |
| `ociPush` | `k8s` | Publishes a folder as an OCI artifact and returns its digest |
| `clusterctlMove` | `k8s` | Runs the pivot and reports what moved |
| `teardownOwned` | `aws` | Lists what a sweep would delete, by ownership tag |

The Ops call these steps against a kind instance they created and during a pivot you asked for. They never apply to a cluster that Flux is already reconciling.

## Where things are recorded

| What | Where |
|---|---|
| Your estate | Your YAML, in Git |
| A run's phases and its result | The `chant/lifecycle` branch, or the steward's thread |
| An approval | The `chant/lifecycle` branch |
| A snapshot for drift comparison | The `chant/lifecycle` branch. It is evidence only, and nothing decides ownership from it |

## Versions

`kit/package.json` pins chant and every lexicon. `kit/UPSTREAM` pins the knr-ops commit that the kit's tests ran against. Renovate updates both, with the same grouping rules as your fork.
