# Why it works this way

## knr-ops is an approach, and the kit leaves it alone

knr-ops manages cloud infrastructure through the Kubernetes API. Git is the source, and controllers reconcile it continuously. There is no state file anywhere. A single control plane covers both infrastructure and workloads, so the same RBAC model and audit trail cover both.

The kit changes none of that. Flux stays the only writer to your clusters. CAPI and ACK stay the only things that call AWS on the estate's behalf.

## The one rule

**If you drop the kit, your knr-ops still works fine.**

The kit is optional, and [Dropping the kit](leaving.md) shows that leaving costs you two `git rm` commands. Every feature had to pass that test before it went in. Several reasonable ideas failed it and stayed out.

One example is chart versions. knr-ops states them in `bootstrap.toml` and again in the `HelmRelease` manifests. Declaring them once in TypeScript would be tidy. It would also make `knr-bootstrap` depend on a chant build, so the kit checks that the two agree and moves nothing.

## "No second toolchain"

The knr-ops README describes the pattern as "no Terraform, no DSLs, no state files, no second toolchain". The kit is a second toolchain, and that is why it is optional.

It helps to be exact about what that phrase protects. knr-ops already uses about ten tools beside `kubectl`, among them kustomize and Renovate. None of them is a problem, because none of them puts a different model between you and the Kubernetes API. HCL does that. A state file does that. The thing being protected is the absence of an abstraction, and the tool count is a separate matter.

The kit holds itself to that standard in three ways.

**It reads your YAML as it is.** Every feature outside typed authoring works on the kustomize roots you already have, and none of them converts a file.

**Its types are the platform's own.** When you opt in to typed authoring, the types come from the CRD schemas the API server validates against. One typed object is one manifest, and the built YAML contains nothing specific to chant. If you stop using chant, the files it wrote keep working.

**The round trip is backed by tools in both directions.**

| Direction | Tool |
|---|---|
| YAML to TypeScript | `chant import --kustomize <dir>` |
| TypeScript to YAML | `chant build` |
| A live cluster to TypeScript | `chant import --from <env>` |
| Live drift back to the line that caused it | `chant lifecycle diff --live` |
| YAML read in place | `k8s.kustomize.roots` |

The one place where the kit steps past 1:1 is a composite such as `CapaEksCluster`, which turns one call into a dozen manifests. It is a further option on top of an option, and [Typed authoring](typed.md#what-a-composite-costs-you) says what it costs.

knr-ops already reviews rendered output for a related reason. A kustomize `namePrefix` and a Flux `postBuild` substitution both change the YAML between the file and the cluster, and konflate exists to show you the result. The kit's output goes through the same review. An empty konflate diff is the acceptance test for a typed conversion.

## Observe, and never apply

chant can apply. In a knr-ops estate it does not, because Flux already does that and a second writer would break the first golden rule. Every scheduled rule in the kit reports, and the build refuses a rule table that tries to do more.

Drift means something specific in an estate where Flux reconciles. Flux reverts a plain edit within its interval. So drift that is still there when the kit looks again says that a `Kustomization` is suspended or stalled, or that something is fighting it. You learn more from that than from "something changed".

## Ownership without a state file

The kit decides whether an object is yours by reading a label on the object. It keeps no record of its own to consult. That is why deleting the `chant/lifecycle` branch changes nothing. The branch holds history and approvals, and nothing reads it to decide what exists.

Flux applies your YAML directly, so the label comes from a `labels:` block in each kustomize root. That is the one change the kit asks you to make to your YAML, and the label does nothing on its own.

## A gate is a fact, never a wait

An approval in the kit is a line on a ledger in Git. A run that reaches an unapproved gate writes down that it is waiting and exits with code 3. No process stays open, so a decision that takes three days costs nothing while you think. Your approval is a second line on the same ledger, and the next run reads it.

A destructive gate is bound to a plan. You approve a specific list of resources. If that list changes before the next run, your approval no longer applies.

## Two drivers for the lifecycle

`knr-bootstrap` and the kit's Ops perform the same steps from the same `bootstrap.toml`. Two drivers can coexist because every step checks what exists before it acts. You can bootstrap with one and tear down with the other.

The Ops exist because a lifecycle run is the one kind of change that leaves no trace in Git. They add a record and an approval, and they leave the steps themselves as they were.
