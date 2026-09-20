# Check the whole estate

`mise run validate` builds each overlay and tells you that it renders. `just check` renders all of them into one build and tells you whether they agree with each other.

```sh
cd kit
just check
```

```
mgmt/aws/clusters/flux-ks.yaml
  FLUX003  Kustomization "eu-west-1" dependsOn "capa-sytem", and no Kustomization has that name

workload/base/rds-instances/flux-ks.yaml
  FLUX010  Kustomization "rds-instances" is not listed in workload/base/kustomization.yaml

2 problems in 5 roots
```

A wrong `dependsOn` name renders without complaint. Flux then holds that `Kustomization` forever, and nothing reports an error. These checks exist for mistakes of that kind.

## What runs

| Rule | It fails when | Why you care |
|---|---|---|
| FLUX001 | A `GitRepository` has a `url` and no `ref` | The default is the `master` branch, which stalls the source |
| FLUX002 | A `sourceRef` names a source that no root declares | The `Kustomization` never gets an artifact. The bootstrap `flux-system` source is exempt |
| FLUX003 | A `dependsOn` name matches no `Kustomization` | Flux waits on it indefinitely |
| FLUX010 | A `flux-ks.yaml` is absent from its parent `kustomization.yaml` | The file reconciles nothing and reports nothing |
| FLUX011 | `spec.path` does not exist in the repo | The `Kustomization` fails at run time with a path error |
| FLUX012 | `postBuild.substituteFrom` names a ConfigMap that no root declares and bootstrap does not inject | `${AWS_REGION}` reaches the cluster as a literal |
| WK8505 | A `*.sops.yaml` file is reachable from a `Kustomization` without `spec.decryption` | Flux applies the ciphertext as the Secret's value |
| KNR001 | A `HelmRelease` version differs from the same chart's version in `bootstrap.toml` | Flux adopts the bootstrap install only when the two agree |
| KNR002 | A name in the `[teardown]` section of `bootstrap.toml` matches no manifest | Teardown would skip a resource that the estate creates |
| CAPI001 | A provider CR's `healthChecks` names a CRD that the provider does not install | Flux reports ready before the provider is |

The standard Kubernetes audit rules run as well. They cover privileged containers and unpinned images, along with the other `WK8` checks.

KNR001 and KNR002 give the same guarantee as the cross-check inside `mise run validate`. They are here so that one command covers the estate.

## Turning a rule off

Put a disable comment on the line above the object, with a reason.

```yaml
# chant-disable-next-line FLUX002 -- source is created by the air-gap bundle
```

`just check` prints every active disable at the end of its report, so a suppression never goes unseen.

## On a pull request

The [estate check workflow](ci.md#estate-checks-on-the-pull-request) runs `just check` and posts the result as one sticky comment beside konflate's. konflate shows you what will change. This comment shows you what is inconsistent.

## What it does not replace

Keep `mise run validate`. It runs yamllint and the Renovate coverage tests, and `knr-bootstrap` relies on its `bootstrap.toml` cross-check. `just check` adds to it.
