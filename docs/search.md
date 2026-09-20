# Ask the estate a question

A question about your estate usually starts with `grep` across `mgmt/` and `workload/`, and ends with you joining the results in your head. `chant search` parses every root into one graph of objects and the references between them. You ask the graph.

```sh
cd kit
npx chant search "kind:Cluster"
```

```
eu-north-1-management   K8s::CAPI::Cluster
eu-north-1-workload     K8s::CAPI::Cluster
eu-west-1-workload      K8s::CAPI::Cluster
— declared only
```

Each match is one line. The last line says what backed the answer.

## Writing a query

Terms are separated by spaces, and an object has to match all of them.

| Term | Matches |
|---|---|
| `word` | Any object whose name, kind or attribute values contain the word |
| `kind:MachinePool` | Objects whose kind contains `MachinePool` |
| `attr:instanceType=g5` | Objects with that attribute value |
| `->kind:X` | Objects that refer to an object of kind X |
| `<-kind:X` | Objects that an object of kind X refers to |

The arrow terms follow the references knr-ops actually uses. That covers `sourceRef`, `dependsOn`, `infrastructureRef`, `controlPlaneRef`, `clusterName` and `issuerRef`. It also covers the label selectors on `HelmChartProxy` and `ClusterResourceSet`.

## Questions worth keeping

Everything that waits on `capa-system`:

```sh
npx chant search "kind:Kustomization ->capa-system"
```

GPU node pools in one region:

```sh
npx chant search "kind:AWSManagedMachinePool attr:instanceType=g5 eu-west-1" --show instanceType,scaling
```

Kustomizations that decrypt a secret:

```sh
npx chant search "kind:Kustomization attr:decrypts=true"
```

Objects reconciled by one `Kustomization`:

```sh
npx chant search "attr:reconciledBy=rds-instances"
```

## Knowing what was left out

An empty `grep` tells you nothing about what it skipped. Add `--explain` and the answer carries its own denominator.

```sh
npx chant search "kind:Cluster <-kind:PodIdentityAssociation" --explain
```

```
eu-north-1-workload     K8s::CAPI::Cluster
— 1 of 3 K8s::CAPI::Cluster matched
  · excluded eu-west-1-workload — fails <-kind:PodIdentityAssociation
  · excluded eu-north-1-management — fails <-kind:PodIdentityAssociation
```

The second line of that footer is the finding. Step 5 of the add-a-cluster procedure in `docs/extending.md` was skipped for `eu-west-1`.

## Asking the cluster

The same query runs against a live environment. The declared graph supplies the references, and the cluster supplies identity and status.

```sh
npx chant search "kind:Cluster" --live --env aws --show phase
```

`--at latest` answers from last night's snapshot, which needs no credentials. `--check-live` re-reads only the rows that matched and tells you whether the snapshot still holds. Add `--fail-on-drift` and the command becomes a CI gate.

A read that fails is reported as a failure. You never get an empty list when the truth is that the cluster could not be reached.

## Derived attributes

The kit computes four attributes before it matches, so that a join across several objects becomes one term.

| Attribute | Meaning |
|---|---|
| `reconciledBy` | The Flux `Kustomization` whose inventory holds the object |
| `clusterRole` | `management` or `workload` |
| `blocked` | A `Kustomization` with a transitive dependency that is not Ready. Live mode only |
| `decrypts` | A `Kustomization` that reaches at least one SOPS file |
