import type { Invoice } from "../types/receivable";

const SUI_ADDRESS_PATTERN = /^0x[0-9a-fA-F]{64}$/;
const WALRUS_BLOB_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const SHA256_PATTERN = /^sha256:[0-9a-fA-F]{64}$/;

export function healthScore(invoice: Invoice) {
  const dueDateMs = new Date(invoice.dueDate).getTime();
  const hasValidDueDate = Number.isFinite(dueDateMs) && dueDateMs > 0;
  const isWithinTerms = hasValidDueDate && dueDateMs > Date.now();
  const dueDateCheck =
    invoice.status === "PAID"
      ? { label: "Due date recorded", passed: hasValidDueDate, points: 15 }
      : { label: "Invoice within terms", passed: isWithinTerms, points: 15 };
  const lifecycleCheck =
    invoice.status === "PAID"
      ? { label: "Settlement completed", passed: true, points: 20 }
      : invoice.status === "OVERDUE" || !isWithinTerms
        ? { label: "Payment status healthy", passed: false, points: 20 }
        : { label: "Invoice open and unpaid", passed: true, points: 20 };

  const checks = [
    { label: "On-chain receivable", passed: SUI_ADDRESS_PATTERN.test(invoice.objectId), points: 10 },
    { label: "Payer wallet verified", passed: SUI_ADDRESS_PATTERN.test(invoice.payer), points: 15 },
    { label: "Payer acknowledged", passed: (invoice.acknowledgedAtMs ?? 0) > 0, points: 10 },
    { label: "Walrus evidence linked", passed: WALRUS_BLOB_PATTERN.test(invoice.blobId), points: 15 },
    { label: "Evidence checksum anchored", passed: SHA256_PATTERN.test(invoice.metadataChecksum ?? ""), points: 15 },
    dueDateCheck,
    lifecycleCheck,
  ];

  return {
    checks,
    score: checks.reduce((sum, check) => sum + (check.passed ? check.points : 0), 0),
  };
}
