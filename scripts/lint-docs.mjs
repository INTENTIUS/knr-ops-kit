// Scores every markdown file with the `sentences` prose linter.
//   node scripts/lint-docs.mjs [strictness 1-3] [max score per file]
// Exits 1 when any file scores above the limit.
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { lintDocument } from "sentences/lint/run";

const strictness = Number(process.argv[2] ?? 2);
const limit = Number(process.argv[3] ?? 8);
const roots = ["README.md", "ROADMAP.md", "docs", "research"];

const files = roots.flatMap((r) =>
  statSync(r).isDirectory()
    ? readdirSync(r).filter((f) => f.endsWith(".md")).sort().map((f) => join(r, f))
    : [r],
);

let failed = false;
for (const file of files) {
  const text = readFileSync(file, "utf8");
  const report = lintDocument(text, { markdown: true, strictness });
  const score = report.score.total;
  const over = score > limit;
  failed ||= over;
  console.log(`${over ? "FAIL" : "ok  "} ${score.toFixed(1).padStart(5)}  ${file}`);
  if (over || process.env.VERBOSE) {
    for (const f of report.findings) {
      const line = text.slice(0, f.span.start).split("\n").length;
      console.log(`       L${line} [${f.ruleId}/${f.severity}] ${f.message}`);
    }
  }
}
process.exit(failed ? 1 : 0);
