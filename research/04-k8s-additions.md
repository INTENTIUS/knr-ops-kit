# Proposed additions to chant's Kubernetes lexicon

Everything in this file applies to any estate built on CAPI, Flux or ACK. That is why it belongs in the lexicon and stays out of the kit. Each section should become a separate chant issue.

## 1. CRD sources

The tables compare the kinds knr-ops uses with `lexicons/k8s/src/generated/lexicon-k8s.json` at the revision studied.

These kinds are already typed.

| knr-ops kind | chant type |
|---|---|
| Flux Kustomization, HelmRelease, OCIRepository, HelmRepository, GitRepository | `K8s::Flux::*` |
| FluxInstance | `K8s::Flux::FluxInstance` |
| Cluster and MachinePool | `K8s::CAPI::*` |
| AWSManagedControlPlane | `K8s::Controlplane::AWSManagedControlPlane` |
| AWSManagedCluster, AWSManagedMachinePool, AWSClusterControllerIdentity | `K8s::Infrastructure::*` |
| HelmChartProxy and ClusterResourceSet | `K8s::Addons::*` |
| PodIdentityAssociation | `K8s::Eks::PodIdentityAssociation` |
| DBInstance | `K8s::Rds::DBInstance` |
| ACK IAM Role and User | `K8s::Iam::*` |
| Certificate and Issuer | `K8s::CertManager::*` |

These kinds returned no match.

| Kind | API group | Where knr-ops uses it |
|---|---|---|
| ClusterClass | `cluster.x-k8s.io` | `local-host` |
| CoreProvider, InfrastructureProvider, BootstrapProvider, ControlPlaneProvider, AddonProvider | `operator.cluster.x-k8s.io/v1alpha2` | Every environment, since this is how providers are declared |
| DevClusterTemplate and DevMachineTemplate | CAPD | `local-host` |
| KubeadmControlPlaneTemplate and KubeadmConfigTemplate | CAPI kubeadm | `local-host` |
| TalosControlPlane | Talos control plane provider | `local-talos` |
| TinkerbellCluster and TinkerbellMachineTemplate | CAPT | `local-talos` |

The five operator provider kinds and `ClusterClass` should come first, because every estate that uses the CAPI operator needs them. CAPD and the kubeadm templates come next, since the path without a cloud account needs them. The Talos and Tinkerbell kinds can wait until the `local-talos` work in knr-ops settles.

Two naming decisions belong in `group-namespace.ts`. The group `operator.cluster.x-k8s.io` would become `K8s::Operator::*` under the default rule, and an override such as `CAPIOperator` would read better. CAPD and Tinkerbell share the group `infrastructure.cluster.x-k8s.io` with CAPA, so all three would share the `K8s::Infrastructure` namespace unless they are split.

## 2. Step builders

Three steps in the knr-ops lifecycle have no chant builder today.

### clusterctlMove

This builder would run the pivot between a source context and a target context, within one namespace. Its output should list what it moved, so that a later step can verify the result.

`clusterctl move` pauses the clusters and copies objects in owner-reference order. It then deletes them from the source. Reimplementing that through the typed client would be a large piece of work, so the first version should wrap the binary.

The builder fits in the Kubernetes lexicon beside the Argo and Flux activities. helm has a lexicon of its own because it has its own file format. clusterctl brings no file format that knr-ops uses, and the CAPI types already live in the Kubernetes lexicon.

The builder's documentation should carry the notes knr-ops already gives its operators. The move is re-runnable. kind stays authoritative until the final deletion. Moved CAPI objects must be left alone during recovery.

### OCI artifact push

The `local-host` environment publishes two folders as the `knr-ops:latest` OCI artifact, and Flux syncs from it. knr-ops uses `flux push artifact` for this. A builder would take a path and a registry reference. It would publish the resulting digest, so that an `OCIRepository` could pin it.

### Suspend and resume

The pivot suspends Flux in kind before the move and starts it on the target afterwards. Both operations are patches through the typed client, and neither needs a binary.

## 3. An EKS workload cluster composite

The working name is `CapaEksCluster`. It would emit what the seven steps in knr-ops `docs/extending.md` produce by hand.

| Emitted resource | Notes |
|---|---|
| `K8s::CAPI::Cluster` | Labelled `fluxcd: enabled` and `region: <region>` |
| `AWSManagedControlPlane` | Includes the `eks-pod-identity-agent` addon |
| `AWSManagedCluster` | |
| `MachinePool` with `AWSManagedMachinePool` | One pair per pool |
| `PodIdentityAssociation` | One per ACK controller |
| Flux `Kustomization` | Depends on `capa-system` |
| FluxInstance ConfigMap with `ClusterResourceSet` | One pair per cluster |

Its props would be `name`, `region`, `kubernetesVersion`, `pools`, `workloadPath` and `clusterVars`. Each pool would carry a name and an instance type, together with an architecture and size limits.

The composite follows the provenance rule from `00-principles.md`. Instance types, versions and pool sizes are parameters with defaults, and so is the sync path. The labels that Flux and the CAPI addons select on are fixed literals, because changing them per caller would break the pattern. The body should avoid `if` statements and array transforms so that chant can still trace each field. The fan-out per pool makes that hard, and a separate `CapaEksPool` composite called once per pool may be the answer.

knr-ops uses a kustomize `namePrefix` with a `capi-nameref.yaml` so that CAPI references pick up the prefix. A composite that derives every name from `name` produces the same final names without either file.

A second composite could cover the S3 bucket and RDS instance pattern in `workload/base`, with the security posture that `docs/workload-resources.md` describes.

## 4. Flux layout checks

knr-ops holds these conventions today through review and `mise run validate`. They apply to any Flux monorepo, so they belong beside FLUX001 to FLUX003.

| Proposed check | What it catches |
|---|---|
| Every Flux `Kustomization` is reachable from a parent kustomize root | A `flux-ks.yaml` that was written and never registered |
| `spec.path` exists in the repository | A path typo that stalls the `Kustomization` at run time |
| A `*.sops.yaml` file is reachable only from a `Kustomization` with `spec.decryption` set | An encrypted Secret applied as ciphertext. chant's SOPS design doc proposes this as WK8505 |
| `postBuild.substituteFrom` names a ConfigMap the build declares or the bootstrap injects | A variable such as `${AWS_REGION}` left unsubstituted |
| A `HelmRelease` version matches the chart version in `bootstrap.toml` | The drift that the knr-ops validate cross-check exists to prevent |
| A provider's `healthChecks` entry names a CRD that provider installs | Flux reporting ready before the provider is |

The first two checks depend on the kustomize rendering that `k8s.kustomize.roots` already does.

## 5. A reference catalog

A lexicon's `referenceCatalog` tells chant how observed resources refer to each other. chant uses it to rebuild edges from live objects and from ingested YAML. Four lexicons declare one today. The Kubernetes lexicon has none.

Without a catalog, objects read from YAML have no edges between them. The edge operators in `chant search` then have nothing to follow. `06-gaps-and-open-questions.md` covers this as gap 2.

A knr-ops estate needs the edges below.

| From | Field | To |
|---|---|---|
| Flux Kustomization or HelmRelease | `spec.sourceRef` | GitRepository, OCIRepository, HelmRepository |
| Flux Kustomization | `spec.dependsOn[]` | Flux Kustomization |
| Flux Kustomization | `spec.decryption.secretRef` | Secret |
| Flux Kustomization | `spec.postBuild.substituteFrom[]` | ConfigMap or Secret |
| CAPI Cluster | `spec.infrastructureRef` | AWSManagedCluster and its peers |
| CAPI Cluster | `spec.controlPlaneRef` | AWSManagedControlPlane and its peers |
| CAPI Cluster | `spec.topology.class` | ClusterClass |
| MachinePool | `spec.clusterName` | Cluster |
| MachinePool | `spec.template.spec.infrastructureRef` | AWSManagedMachinePool |
| HelmChartProxy or ClusterResourceSet | `spec.clusterSelector` | Cluster, matched by label |
| PodIdentityAssociation | `spec.clusterName` and `spec.roleARN` | Cluster and ACK IAM Role |
| Certificate | `spec.issuerRef` | Issuer or ClusterIssuer |

The same catalog should hold the core references, such as owner references and `serviceAccountName`. Those help every user of the Kubernetes lexicon.

Edges that come from a label selector differ from name references. They may need catalog support that chant lacks today.

## 6. Derived attributes

`chant search` computes attributes such as `internetFacing` for AWS instances, which turns a join across several hops into a single term. A CAPI and Flux estate could use similar attributes.

| Attribute | Meaning |
|---|---|
| `reconciledBy` | The Flux `Kustomization` whose inventory holds the object |
| `clusterRole` | Whether an object lives on the management side or a workload side |
| `blocked` | A `Kustomization` with a transitive dependency that is not Ready |
| `decrypts` | A `Kustomization` that reaches at least one SOPS file |

These are ideas for later, and the first version needs none of them.
