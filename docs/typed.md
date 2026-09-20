# Typed authoring

This part is optional. You choose it one directory at a time, and you can take it back one directory at a time.

You write objects in TypeScript and `chant build` turns them into plain manifests. Those manifests are committed at the path Flux already syncs. Flux keeps reading YAML from Git and never learns that anything changed.

## What you are getting

The types are the CRDs' own schemas. chant generates them from the same OpenAPI documents the API server validates against, so `K8s::CAPI::Cluster` has exactly the fields a `Cluster` has. One typed object becomes one manifest. There is no second vocabulary to learn, and nothing sits between you and the Kubernetes API.

You get three things for that. A misspelled field fails in your editor, where today it fails in Flux. A reference between two objects is a real reference, so renaming one side updates the other. Your editor completes `spec` for every kind knr-ops uses, including the CAPI operator providers and the ACK controllers.

## Converting a directory

```sh
cd kit
npx chant import --kustomize ../mgmt/aws/clusters/eu-west-1 -o src/clusters/eu-west-1
npx chant build
```

`import` renders the kustomization and writes one typed declaration per object. `build` writes the manifests back to `mgmt/aws/clusters/eu-west-1/`, because `chant.config.ts` maps each source directory to its output path.

Open a pull request with both the TypeScript and the rebuilt YAML.

## The acceptance test

**konflate must show no diff.**

konflate already renders what Flux will apply and compares it with `main`. A conversion changes how the YAML is authored and must change nothing about what reconciles, so the rendered diff has to be empty. If konflate shows a change, the conversion is wrong. Fix it before you merge.

The kit's own test suite runs this check against the pinned upstream commit for every root.

## Going back

Delete the directory under `kit/src/` and keep the committed YAML. konflate shows no diff again, and you are back to editing that YAML by hand. Nothing else needs undoing.

## A workload cluster in one call

`docs/extending.md` in knr-ops lists seven steps for adding a workload cluster. `CapaEksCluster` emits the same objects from one declaration.

```ts
import { CapaEksCluster } from "@intentius/chant-lexicon-k8s";

export const euCentral = CapaEksCluster({
  name: "eu-central-1-workload",
  region: "eu-central-1",
  kubernetesVersion: "v1.33",
  workloadPath: "./workload/eu-central-01",
  pools: [
    { name: "arm", instanceType: "m7g.large", arch: "arm64", min: 1, max: 4 },
    { name: "gpu", instanceType: "g5.xlarge", arch: "amd64", gpu: true, min: 0, max: 2 },
  ],
});
```

| It emits | Matching step in `extending.md` |
|---|---|
| `Cluster`, `AWSManagedControlPlane` with the pod identity addon, `AWSManagedCluster` | 1 and 2 |
| A `MachinePool` and an `AWSManagedMachinePool` for each pool | 1 |
| The Flux `Kustomization`, depending on `capa-system` | 3 |
| The FluxInstance ConfigMap and its `ClusterResourceSet` | 4 |
| A `PodIdentityAssociation` for each ACK controller | 5 |
| `workload/eu-central-01/kustomization.yaml` pointing at `../base` | 6 |

Names derive from `name`, so the output needs no `namePrefix` and no `capi-nameref.yaml`.

### What a composite costs you

A composite is the one place where the output is not 1:1 with what you wrote. That has a price when the kit traces drift back to source.

A field you passed as a parameter traces cleanly. If `maxSize` drifts, the kit proposes a one-line change to `max` in the call above. A field the composite fixes cannot be changed from your call, and the kit says so by name when asked.

`CapaEksCluster` fixes only what the pattern depends on. That is the `fluxcd: enabled` and `region` labels that the addons select on, and the pod identity addon. Everything an operator might change under pressure is a parameter with a default.

If you want types and no grouping at all, use the generated classes alone. `chant import` produces exactly that.

## Mixing both

A fork can keep `mgmt/aws/clusters/` typed and `workload/base/` hand-written indefinitely. Both reach Flux as committed YAML. `just check` sees the typed directories through the build and the hand-written ones through the kustomize roots, in a single run.

## What stays in `bootstrap.toml`

Chart versions and teardown names stay there, even in a fully typed fork. `knr-bootstrap` reads that file, and it has to keep working when the kit is gone. Rule KNR001 keeps the `HelmRelease` versions in step with it.
