# Principles

Every other file in this folder is judged against the five principles below.

## 1. knr-ops is an approach, and the kit leaves it unchanged

The pattern manages cloud infrastructure through the Kubernetes API. Git is the source and controllers reconcile it continuously. There are no state files. A single control plane covers both infrastructure and workloads, so the same RBAC model applies to both.

The kit alters none of this. Flux stays the only writer to the clusters. CAPI and ACK stay the only components that call AWS on the estate's behalf.

## 2. The drop test

**If you drop chant, your knr-ops still works fine.**

A team might delete the kit directory and remove its CI jobs. The estate must then reconcile exactly as it did before, and the team must need no migration step. Every proposal in this folder has to pass that test.

The table shows how each area passes.

| Area | Why it passes |
|---|---|
| Reconcile path | Flux reads committed YAML from the same paths it reads today, and chant is never on that path |
| In-cluster footprint | The kit installs no CRDs and no controllers. Its ownership label is inert. A scheduled `chant operator` job is optional and removable |
| State | chant hosts no state file. The `chant/lifecycle` branch holds run history and approvals, and deleting it changes nothing in a cluster |
| Lifecycle CLI | `knr-bootstrap` and the shell scripts stay in the repo and keep working. The kit's Ops are a second driver over the same steps |
| `bootstrap.toml` | It stays authoritative, and the kit only reads it |
| Typed authoring | `chant build` writes plain manifests, committed at the paths Flux already syncs. A team that stops running it goes back to editing that YAML by hand |
| CI | Every proposed job is additive. `validate` and `konflate` stay as they are |
| Agents | The hosted runner and the review agent are tools for operators, and nothing that reconciles depends on them |

Some designs would fail the test, so they are excluded.

- A Flux `Kustomization` must never point at a directory that only `chant build` fills and that is absent from Git.
- chant must never apply anything to a knr-ops cluster.
- A scheduled rule must never start an Op that changes the estate.
- Chart versions and teardown names must stay in `bootstrap.toml`, because the Rust CLI reads them there.
- A chant job must never be the only merge gate.
- No value the estate needs for reconciling may live only in a chant ledger.

## 3. Typing adds a toolchain and no abstraction

The knr-ops README describes the pattern as "no Terraform, no DSLs, no state files, no second toolchain". chant is a second toolchain, which is the reason the kit is optional. The drop test keeps that option honest.

This design reads the phrase as a statement about abstractions. knr-ops already uses about ten tools beside `kubectl`, and `01-knr-ops.md` lists them. None of them places a different model between the engineer and the Kubernetes API. HCL would, and so would a state file. Under that reading, a tool beside knr-ops is acceptable when it introduces no abstraction of its own. Whether the knr-ops author reads the phrase the same way is a question listed in `06-gaps-and-open-questions.md`.

chant's typed classes meet that condition for two reasons.

The first reason is that the types are 1:1 with the platform spec. The Kubernetes lexicon generates them from the OpenAPI and CRD schemas that the API server validates against. One typed object is one manifest. The serializer supplies `apiVersion` and `kind`, and it writes the other fields as authored. chant's philosophy page calls this "spec-true" and states the consequence plainly. "If you stop using chant, the artifacts keep working. There's nothing chant-specific in the output."

A typed `K8s::CAPI::Cluster` is therefore the same declaration as the YAML `Cluster`, checked earlier. It uses the Kubernetes API's own vocabulary. The same controllers reconcile it, and konflate reviews the same rendered diff.

The second reason is that tooling backs the round trip in both directions.

| Direction | Tool |
|---|---|
| YAML to TypeScript | `chant import --kustomize <dir>` renders a kustomization and imports the result |
| TypeScript to YAML | `chant build` |
| Live cluster to TypeScript | `chant import --from <env>` |
| Live drift back to source | `chant lifecycle diff` traces a drifted field to the declaration that produced it |
| YAML read in place | `k8s.kustomize.roots` renders existing overlays into the build and converts nothing |

The last row matters most for knr-ops, because the first adoption level converts nothing at all.

### The exception

chant's docs state the exception directly. "A composite is the one thing chant emits that is not one to one with its source." An EKS workload cluster written that way would turn one call into about a dozen manifests.

Composites are therefore a further optional step. They pass the drop test, because their output is plain committed YAML. Their cost appears when live drift is traced back to source. A field that the composite fixes as a literal cannot be changed at the call site, and chant refuses any such request by name. The composite proposed in `04-k8s-additions.md` makes every field an operator might change a parameter.

A team that wants typing without any grouping uses the generated classes alone and stays strictly 1:1.

knr-ops already reviews rendered output for a related reason. A kustomize `namePrefix` and a Flux `postBuild` substitution both change the YAML between the file and the cluster, and konflate shows the result. chant's output gets the same review.

## 4. A conversion is accepted when konflate shows no diff

knr-ops already has the right judge. A pull request that converts a directory to chant-built YAML must produce an empty konflate rendered diff. An empty diff shows that the conversion changed the authoring alone.

The same check proves the drop test for typed authoring. A team deletes the TypeScript and keeps the committed YAML, and konflate again shows no diff.

chant's own test is weaker. The Kubernetes lexicon's `full-roundtrip` test passes when the re-parsed output has the same number of resources with matching kinds. Exact comparison is skipped because key order and quoting differ between input and output. That is reasonable for a lexicon test, and it is too weak to support a 1:1 claim to knr-ops users. The kit's test suite should import every root from a pinned knr-ops commit and build it. It should then compare the rendered output of both sides.

## 5. Adoption is per directory and reversible

A fork can keep `mgmt/aws/clusters/` typed and `workload/base/` hand-written for as long as it likes. Both directories reach Flux as committed YAML. chant's checks see the typed one through the build and the hand-written one through `k8s.kustomize.roots`.
