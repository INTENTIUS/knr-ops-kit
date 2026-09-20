# Add it to your fork

You need Node 20 or newer and `just`. Everything else comes from the toolchain knr-ops already pins with mise.

## 1. Copy the kit in

```sh
cd your-knr-ops-fork
npx degit INTENTIUS/knr-ops-kit/kit kit
cd kit
npm install
```

The kit lives in `kit/` and touches nothing outside it. Your `mgmt/`, `workload/` and `bootstrap.toml` stay where they are.

```
your-knr-ops-fork/
  mgmt/  workload/  airgap/  bootstrap.toml  ...     unchanged
  kit/
    chant.config.ts     which roots to read, which context belongs to which environment
    ops/                bootstrap, pivot, teardown, watch, converge
    src/                empty until you opt in to typed authoring
    justfile
    SKILL.md            the capability map your coding agent reads
    UPSTREAM            the knr-ops commit this kit version was tested against
```

## 2. Point it at your roots

`kit/chant.config.ts` lists the kustomize roots to read. The defaults match upstream knr-ops, so a fork that kept the layout needs no edit. Add a line for each workload cluster you have added.

```ts
export default {
  lexicons: ["k8s", "helm", "kind", "zarf", "aws", "github"],
  sourceDir: "src",
  ownership: { stack: "knr-ops", env: { param: "env" } },
  environments: ["local-host", "local-host-bootstrap", "aws", "aws-bootstrap"],
  k8s: {
    kustomize: {
      roots: {
        "mgmt-aws": "../mgmt/aws",
        "mgmt-local-host": "../mgmt/local-host",
        "workload-eu-north-01": "../workload/eu-north-01",
        "workload-eu-west-01": "../workload/eu-west-01",
        "workload-local-host": "../workload/local-host",
      },
    },
    profiles: {
      "local-host-bootstrap": { context: "kind-mgmt" },
      "local-host": { context: "knr-ops-mgmt" },
      "aws-bootstrap": { context: "kind-mgmt" },
      aws: { context: "knr-ops-mgmt" },
    },
  },
} satisfies ChantConfig;
```

Each knr-ops environment appears twice. The `-bootstrap` form is pinned to the kind context, and the plain form is pinned to the self-managed cluster that exists after the pivot. [Read a live cluster](clusters.md) explains why that matters.

## 3. Run the checks

```sh
just check
```

This renders every root into one build, then runs lint and audit over the result. A fresh upstream checkout passes. [Check the whole estate](checks.md) lists what each rule catches.

You can stop here. Steps 4 and 5 are only for the features that read a live cluster.

## 4. Add the ownership label

The live features report on objects that carry the kit's ownership label. Flux applies your YAML directly, so the label has to come from your kustomize roots. Add this block to the top-level `kustomization.yaml` of each root.

```yaml
labels:
  - pairs:
      chant.intentius.io/stack: knr-ops
    includeSelectors: false
```

The label is inert. No controller selects on it, and removing it later changes nothing in the cluster. `just label-check` tells you which roots still lack it.

## 5. Confirm the contexts

```sh
just doctor
```

`doctor` checks the pinned tools and the kubeconfig contexts named in `chant.config.ts`. It also confirms that `bootstrap.toml` parses. It prints the command to run for anything that is missing.

## What you did not have to do

You did not convert any YAML or change `knr-bootstrap`. Nothing was installed into a cluster. If you delete `kit/` now, the only trace is the label from step 4, which does nothing on its own.
