# knr-ops as studied

This file describes knr-ops at commit `f6b8d34`. It records what the kit has to fit around. The project is "kubernetes-native resource operations" from Polar Squad, published under Apache 2.0 at `https://github.com/polarsquad/knr-ops`.

## What it is

knr-ops is a GitOps pattern for managing cloud infrastructure through the Kubernetes API, together with a working reference implementation. The README states that it "is not a product" and invites readers to fork it and adapt the layout.

After a one-time bootstrap and pivot, the README says, "everything is declared in Git as YAML". The intended readers are platform engineers who already run Kubernetes.

## The chain

1. A disposable local kind node group bootstraps Flux.
2. Flux installs CAPI and a provider, which provision a management cluster.
3. A CAPI pivot with `clusterctl move` transfers control to that management cluster. It then reconciles itself from Git, and the kind instance is deleted.
4. Flux on the management side reconciles the workload clusters. It delivers a Flux instance to each one through CAPI addons, using a `HelmChartProxy` and a `ClusterResourceSet`.
5. Each workload Flux instance reconciles its own apps.

## Environments

| Environment | Provider | What it reconciles |
|---|---|---|
| `aws` | CAPA | A self-managed EKS management cluster and two EKS workload clusters in `eu-north-1` and `eu-west-1`. The workload side has four node pools across ARM and GPU. ACK operators manage S3 buckets, RDS instances and IAM roles |
| `local-host` | CAPD | A local OCI registry, a small workload cluster, a second Flux instance and Podinfo. It needs no cloud account |
| `local-talos` | Talos with Tinkerbell | A single-node management cluster synced from GitHub. The work is in progress under knr-ops issue #105 |

A Zarf bundle packages the `local-host` environment for offline installs. Builds are signed and carry per-component SBOMs. A nightly workflow deploys the bundle two ways. One run monitors public traffic, and the other blocks egress.

## Layout

```
mgmt/aws/                 synced by the management cluster's Flux
  infrastructure/         cert-manager, CAPI operator, CAPA identity, ACK controllers,
                          pod-identity roles, account-global IAM, konflate
  capi-providers/         capi-system, capa-system (SOPS creds), caaph-system
  addons/flux-apps/       installs Flux on each workload cluster
  clusters/               EKS cluster definitions per region, plus clusters/management/
mgmt/local-host/          same layout, CAPD, OCI-synced
mgmt/local-talos/         same layout without addons
workload/base/            ACK controllers and S3/RDS/IAM custom resources
workload/<region>-01/     per-cluster overlay pointing at ../base
workload/local-host/      Podinfo overlay
airgap/                   zarf.yaml, images.txt, build/render/stage scripts
bootstrap-rs/             knr-bootstrap, the Rust lifecycle CLI, and the toolbox Dockerfile
bootstrap.toml            repository-owned lifecycle configuration
bootstrap.sh pivot.sh teardown.sh   shell equivalents of the CLI's phases
tests/                    config and Renovate coverage cross-checks
renovate.json5            dependency discovery and grouping
```

### The component convention

Every component pairs a plain kustomize root with a Flux `Kustomization`.

```
<scope>/<component>/
  kustomization.yaml   lists the manifests, plus flux-ks.yaml
  flux-ks.yaml         Flux Kustomization(s): path, dependsOn, wait
  ...                  raw manifests
```

A new component is registered in the parent `kustomization.yaml`. Ordering uses `dependsOn` with `wait: true`. Per-cluster values such as `${AWS_REGION}` come from `postBuild.substituteFrom: cluster-vars`.

### The golden rules

These are quoted in substance from the knr-ops `AGENTS.md`.

1. Edit YAML in Git, and never mutate the clusters.
2. Flux tracks `main`, so nothing reconciles until it is merged.
3. Secrets use SOPS with age. Encrypted files are named `*.sops.yaml`, and the age key is never committed.
4. Run `mise run validate` before pushing. Pull requests are reviewed as rendered Flux diffs by konflate, which runs as a GitHub Actions merge gate with an in-cluster instance behind it.

## The lifecycle CLI

The one-time part of the lifecycle is a Rust CLI named `knr-bootstrap`, shipped as a toolbox container. It is a behavioural port of the shell scripts with rerun-safe semantics added. The `local-host` environment has passed a full parity run. AWS parity still gates the retirement of the scripts.

Native runs need `kind`, `helm`, `kubectl`, `clusterctl` and `mise`.

The steps below come from `docs/bootstrap-cli.md`.

| Step | What it does |
|---|---|
| Preflight | Validates the environment and tools, and selects a container engine. For AWS it also checks the GitHub token and the age key |
| Bootstrap kind | Creates or reuses the `mgmt` kind instance and installs the Flux Operator. It creates the Git and SOPS secrets, or publishes the local OCI artifact. It then installs the `FluxInstance` and watches reconciliation |
| Pivot | Waits for the CAPI-managed management cluster and exports its kubeconfig. It installs cert-manager, the CAPI operator and the provider CRs at the versions in `bootstrap.toml`. It suspends Flux in kind, runs `clusterctl move`, and seeds Flux on the target. It deletes kind after safety checks |

When a phase fails, the operator fixes the cause and reruns the command. `clusterctl move` is re-runnable, and kind stays authoritative until the final deletion.

Teardown runs in reverse order. For `local-host` it removes the CAPD workload cluster first and the registry last. For AWS it finds the active controller host and deletes the workload clusters. It then sweeps orphaned resources in both workload regions, and it removes the `clusterawsadm` CloudFormation stack.

### bootstrap.toml

This file holds the values specific to the repository that the binary needs.

| Section | Contents |
|---|---|
| `[bootstrap]` | Cluster names, kubeconfig contexts, secret names and the Git branch |
| `[charts]` | Versions of `flux-operator`, `cert-manager` and `capi-operator` |
| `[teardown]` | The CloudFormation stack name, the IAM roles and users that ACK creates, and the S3 bucket name pattern |
| `[environments.*]` | Sync path, management cluster name and timeouts per environment |

The chart versions are installed before Flux exists. They must match the `HelmRelease` versions under `mgmt/<env>/` so that Flux adopts the installs without drift. `mise run validate` checks that they match, and Renovate updates both sides together. A Python test checks the `[teardown]` names against the manifests that define them.

## Tools in use

| Tool | Role in knr-ops |
|---|---|
| mise | Pins tool versions and defines every task |
| kustomize | Builds each overlay |
| Flux CLI and Flux Operator | Bootstrap and reconciliation |
| helm | Chart installs before Flux exists |
| clusterctl | The pivot |
| sops with age | Secret encryption |
| `knr-bootstrap` | The lifecycle CLI |
| Renovate | Dependency updates, with a tested custom-manager setup |
| konflate | Rendered pull request review |
| Zarf | The air-gap bundle |

## Kinds in use

The counts below cover `mgmt/`, `workload/` and `airgap/`.

| Count | Kind |
|---|---|
| 83 | Kustomization, counting both the kustomize and the Flux kind |
| 31 | CustomResourceDefinition |
| 19 | Namespace |
| 13 | HelmRelease |
| 7 | OCIRepository |
| 6 | HelmRepository, PodIdentityAssociation, Cluster |
| 5 | MachinePool, AWSManagedMachinePool, Issuer, Certificate |
| 4 | DevMachineTemplate, ControlPlaneProvider, ClusterResourceSet, BootstrapProvider |
| 3 | InfrastructureProvider, CoreProvider, AWSManagedControlPlane, AWSManagedCluster |
| 2 | KubeadmControlPlaneTemplate, KubeadmConfigTemplate, HelmChartProxy, DevClusterTemplate, ClusterClass, AddonProvider |
| 1 | ZarfPackageConfig, User, TinkerbellMachineTemplate, TinkerbellCluster, TalosControlPlane, FluxInstance, DBInstance, Bucket, AWSClusterControllerIdentity |

The usual RBAC, Service, Deployment, ConfigMap, Secret and webhook kinds appear as well.

Two files look like manifests and are never sent to an API server. The first is the kind config with `apiVersion: kind.x-k8s.io/v1alpha4`, which is generated inline in `bootstrap.sh:63`, `bootstrap-rs/src/main.rs:368` and one airgap script. The second is `airgap/zarf.yaml`, whose kind is `ZarfPackageConfig`.

## Extending it

`docs/extending.md` documents adding a workload cluster as seven steps.

1. Create `mgmt/aws/clusters/<region>/<env>/` with a `cluster.yaml` and a `kustomization.yaml` that sets `namePrefix`. Add a `capi-nameref.yaml` so that CAPI cross-references get the prefix.
2. Label the `Cluster` with `fluxcd: enabled` and `region: <region>`. Include the `eks-pod-identity-agent` addon in the `AWSManagedControlPlane`.
3. Register the directory in the region's `kustomization.yaml`. A new `Kustomization` in `mgmt/aws/clusters/flux-ks.yaml` then depends on `capa-system`.
4. Put a per-region FluxInstance ConfigMap and a matching `ClusterResourceSet` in `mgmt/aws/addons/flux-apps/flux-instance.yaml`.
5. Declare a `PodIdentityAssociation` in `mgmt/aws/infrastructure/ack-pod-identity/pod-identity-associations.yaml`.
6. Create `workload/<region>-01/kustomization.yaml` pointing at `../base`.
7. Run `mise run validate`, then commit and push.

A provider is added as a directory under `mgmt/aws/capi-providers/<name>-system/`. The directory holds a typed CAPI operator CR from `operator.cluster.x-k8s.io/v1alpha2` with a pinned version. Its `flux-ks.yaml` entry depends on `capi-system` and names one CRD the provider installs as a health check. knr-ops pins CAPI core v1.14.0 on the v1beta2 contract.

## What knr-ops already covers

The kit leaves these areas alone, because knr-ops has them in place.

- `local-host` gives a path that needs no cloud account.
- konflate gives rendered pull request review as a merge gate.
- Renovate handles dependency updates, with its own test harness.
- The air-gap bundle is signed and carries SBOMs, and a nightly job verifies it with egress blocked.

## Where chant already refers to knr-ops

- `lexicons/k8s/src/composites/flux-app.ts:32` uses the knr-ops name `sops-age` as the default `secretRef`.
- `docs/design/committed-encrypted-sops-provenance.md` names knr-ops as its reference estate.
- Commit `d5ba61ed` added a `decryption` pass-through to `FluxAppFor` for SOPS Kustomizations.
- `~/checkouts/iac-cd-bench/tasks/knr-ops` holds six benchmark tasks against it.
