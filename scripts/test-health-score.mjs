import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import ts from "typescript";

const source = await readFile(new URL("../src/lib/healthScore.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText;
const { healthScore } = await import(`data:text/javascript;base64,${Buffer.from(compiled).toString("base64")}`);

const verifiedInvoice = {
  objectId: `0x${"1".repeat(64)}`,
  payer: `0x${"2".repeat(64)}`,
  acknowledgedAtMs: 1,
  blobId: "A".repeat(43),
  metadataChecksum: `sha256:${"a".repeat(64)}`,
  dueDate: "2099-01-01",
  status: "PENDING",
};

assert.equal(healthScore(verifiedInvoice).score, 100, "verified pending invoice should score 100");
assert.equal(
  healthScore({ ...verifiedInvoice, status: "PAID", dueDate: "2020-01-01" }).score,
  100,
  "paid invoice should retain a full score after its due date",
);
assert.equal(
  healthScore({ ...verifiedInvoice, status: "OVERDUE", dueDate: "2020-01-01" }).score,
  65,
  "overdue invoice should lose only due-date and lifecycle points",
);
assert.equal(
  healthScore({ ...verifiedInvoice, status: "PENDING", dueDate: "2020-01-01" }).score,
  65,
  "past-due pending invoice should not retain lifecycle points before mark_overdue runs",
);
assert.equal(
  healthScore({ ...verifiedInvoice, acknowledgedAtMs: 0 }).score,
  90,
  "unacknowledged invoice should lose acknowledgement points",
);
assert.equal(
  healthScore({ ...verifiedInvoice, blobId: "mock_walrus_blob" }).score,
  85,
  "placeholder Walrus evidence should not receive evidence-link points",
);
assert.equal(
  healthScore({ ...verifiedInvoice, status: "PAID", dueDate: "invalid" }).score,
  85,
  "paid invoice with an invalid due date should not receive due-date points",
);

for (const invoice of [
  verifiedInvoice,
  { ...verifiedInvoice, status: "PAID", dueDate: "2020-01-01" },
  { ...verifiedInvoice, status: "OVERDUE", dueDate: "2020-01-01" },
  { ...verifiedInvoice, status: "PENDING", dueDate: "2020-01-01" },
]) {
  const result = healthScore(invoice);
  assert.ok(result.score >= 0 && result.score <= 100, "score must stay within 0-100");
  assert.equal(result.checks.reduce((sum, check) => sum + check.points, 0), 100, "weights must total 100");
}

console.log("Health score scenarios passed.");
