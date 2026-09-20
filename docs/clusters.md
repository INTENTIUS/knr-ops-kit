# Read a live cluster

`kubectl get` tells you what exists. `chant kube get` adds the part you usually work out by hand, which is whether each object matches Git.

```sh
cd kit
npx chant kube get machinepools -A --env aws
```

```
NAMESPACE  NAME                          READY  VERDICT
default    eu-north-1-workload-arm       True   declared
default    eu-north-1-workload-gpu       True   drifted
default    eu-west-1-workload-arm        True   declared
default    scratch-pool                  True   orphan
```

| Verdict | Meaning |
|---|---|
| `declared` | The object is in Git and the live fields match |
| `drifted` | The object is in Git and a field that Git sets has a different live value |
| `runtime` | A controller created it on behalf of a declared object, such as a `Machine` |
| `orphan` | It carries the ownership label and nothing in Git declares it |

The verdicts cover objects that carry the [ownership label](getting-started.md#4-add-the-ownership-label). Anything without the label is foreign, and the kit never reports on it.

## The right cluster, every time

A knr-ops environment has two management contexts during its life. Before the pivot the control plane is `kind-mgmt`. After it, the control plane is the self-managed cluster, and kind is gone. A read against the wrong one reports every object as missing.

The kit pins each environment to one context and sends that context with every request.

| Environment | Context | Use it |
|---|---|---|
| `local-host-bootstrap`, `aws-bootstrap` | `kind-mgmt` | From bootstrap until the pivot completes |
| `local-host`, `aws` | `knr-ops-mgmt` | From the pivot onwards |

If your kubeconfig's current context disagrees with the environment you named, the command refuses before it reads anything.

```
k8s: environment "aws" is bound to context "knr-ops-mgmt", and the current context is "kind-mgmt".
Refusing to read. Pass --context to override, or switch context.
```

Workload clusters are separate stacks under the same environment. Name one with `--stack`.

```sh
npx chant kube get buckets --env aws --stack workload-eu-north-01
```

## From an object back to its file

knr-ops applies a `namePrefix` to the cluster directories, so a live name such as `eu-west-1-workload` appears nowhere in the repo as written. `source` does the mapping.

```sh
npx chant kube source cluster eu-west-1-workload --env aws
```

```
mgmt/aws/clusters/eu-west-1/workload/cluster.yaml   (document 1, kind Cluster, name "workload")
  via kustomize root mgmt/aws/clusters/eu-west-1, namePrefix "eu-west-1-"
  reconciled by Kustomization flux-system/eu-west-1
```

## Seeing the drift

```sh
npx chant lifecycle diff --live --env aws
```

```
drifted   K8s::Infrastructure::AWSManagedMachinePool  eu-north-1-workload-gpu
  spec.scaling.maxSize   declared 2   live 6   last written by "kubectl-edit"
```

Flux writes as `kustomize-controller`. The kit treats the fields that manager owns as the declared side, and it names the manager that last wrote a field that differs. Drift here usually means that Flux is suspended or that someone is fighting it, because Flux reverts a plain edit within its interval.

## Credentials

On EKS your kubeconfig authenticates with `aws eks get-token`. That plugin is on the kit's allowlist, the token is cached for the session, and the observation records which credential path produced it. Any other exec plugin is refused by name until you add it to `k8s.execCredentialPlugins`.

## Writes

`chant kube apply` and `chant kube delete` exist, and the kit's `justfile` never calls them. The first knr-ops golden rule holds here too. Make the change in Git and let Flux converge.
