import assert from "node:assert/strict";
import { calculateWalletReputation } from "../functions/_shared/receivables.js";

const payer = `0x${"1".repeat(64)}`;
const issuer = `0x${"2".repeat(64)}`;
const base = {
  issuer_wallet: issuer,
  payer_wallet: payer,
  buyer_wallet: null,
  acknowledged_at_ms: 1,
  status: "PENDING",
  deposit_status: null,
  deposit_depositor: null,
  settlement_status: null,
  settlement_payer: null,
};

assert.equal(calculateWalletReputation(payer, []).score, 50, "new wallets start neutral");
assert.equal(
  calculateWalletReputation(payer, [{ ...base, status: "PAID" }]).score,
  59,
  "acknowledgement and payment add only their documented weights",
);
assert.equal(
  calculateWalletReputation(payer, [{ ...base, status: "OVERDUE" }]).score,
  33,
  "an acknowledged default is penalized",
);
assert.equal(
  calculateWalletReputation(payer, [{ ...base, settlement_payer: payer, settlement_status: "RELEASED" }]).score,
  59,
  "completed settlement history is rewarded",
);
assert.equal(
  calculateWalletReputation(payer, [{ ...base, settlement_payer: payer, settlement_status: "REFUNDED" }]).score,
  48,
  "an abandoned settlement has a small penalty",
);

const saturated = calculateWalletReputation(
  payer,
  Array.from({ length: 20 }, (_, index) => ({ ...base, status: index < 10 ? "PAID" : "OVERDUE" })),
);
assert.ok(saturated.score >= 0 && saturated.score <= 100, "score stays inside 0-100");

console.log("Reputation scenarios passed.");
