export type WalletRole = "issuer" | "buyer" | "payer";

export type Page = "landing" | "dashboard" | "create" | "marketplace" | "portfolio";

export type InvoiceStatus = "PENDING" | "PAID" | "OVERDUE";

export type FinancingStatus = "NOT_LISTED" | "LISTED" | "FINANCED" | "CANCELLED";

export type DepositStatus = "LOCKED" | "RELEASED" | "CLAIMED";

export type SettlementStatus = "ESCROWED" | "RELEASED" | "REFUNDED";

export type Reputation = {
  wallet: string;
  score: number;
  totalInvoices: number;
  acknowledgedInvoices: number;
  invoicesPaid: number;
  defaults: number;
  bondsHonored: number;
  depositsClaimed: number;
  settlements: number;
  settlementRefunds: number;
};

export type Evidence = {
  invoicePdf: boolean;
  lineItemsMatch: boolean;
  payerWalletPresent: boolean;
  dueDateValid: boolean;
  unpaid: boolean;
  evidenceComplete: boolean;
  walrusAvailable: boolean;
};

export type Invoice = {
  id: string;
  packageId?: string;
  objectId: string;
  clientName: string;
  clientEmail: string;
  description: string;
  amount: number;
  dueDate: string;
  issuer: string;
  payer: string;
  paymentRecipient: string;
  buyer: string | null;
  status: InvoiceStatus;
  financingStatus: FinancingStatus;
  financingPrice: number;
  blobId: string;
  blobObjectId?: string;
  metadataChecksum?: string;
  txDigest?: string;
  acknowledgedAtMs?: number;
  acknowledgedTx?: string;
  depositEscrowId?: string;
  depositStatus?: DepositStatus;
  depositDepositor?: string;
  depositAmount?: number;
  depositGracePeriodMs?: number;
  depositTx?: string;
  settlementEscrowId?: string;
  settlementStatus?: SettlementStatus;
  settlementPayer?: string;
  settlementAmount?: number;
  settlementDeliveryConfirmed?: boolean;
  settlementDeadlineMs?: number;
  settlementDeliveryProofBlobId?: string;
  settlementTx?: string;
  issuerReputation?: Reputation;
  payerReputation?: Reputation;
  buyerReputation?: Reputation;
  evidence: Evidence;
  events: string[];
};

export type DemoWallet = {
  label: string;
  address: string;
  balance: number;
};
