#[test_only]
module invofi::receivable_escrow_tests {
    use std::string;
    use invofi::receivable;
    use invofi::receivable_escrow;
    use sui::clock;
    use sui::coin;
    use sui::sui::SUI;
    use sui::tx_context;

    #[test]
    fun paid_invoice_releases_deposit_to_depositor() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x0, 1, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x0, 2, 0, 0, 0);
        let mut invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x0, 100, &mut issuer_ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(
            &invoice,
            @0x0,
            25,
            100,
            0,
            &mut issuer_ctx,
        );
        let payment = coin::mint_for_testing<SUI>(100, &mut payer_ctx);

        receivable::pay_invoice(&mut invoice, payment, &mut payer_ctx);
        receivable_escrow::release_deposit(escrow, &invoice, &mut issuer_ctx);

        receivable::destroy_for_testing(invoice);
    }

    #[test]
    fun default_claim_follows_financed_payment_recipient() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x0, 10, 0, 0, 0);
        let mut buyer_ctx = tx_context::new_from_hint(@0x0, 11, 0, 0, 0);
        let mut invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x3, 100, &mut issuer_ctx);
        let config = receivable::platform_config_for_testing(@0x0, @0x9, 0, &mut issuer_ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(
            &invoice,
            @0x3,
            40,
            100,
            0,
            &mut issuer_ctx,
        );
        let financing_payment = coin::mint_for_testing<SUI>(90, &mut buyer_ctx);
        let mut test_clock = clock::create_for_testing(&mut issuer_ctx);

        receivable::set_acknowledged_for_testing(&mut invoice, 1);
        receivable::list_for_financing(&mut invoice, 90, 1000, &mut issuer_ctx);
        receivable::buy_receivable(&mut invoice, &config, financing_payment, &mut buyer_ctx);
        clock::set_for_testing(&mut test_clock, 1101);

        receivable_escrow::claim_deposit(escrow, &invoice, &test_clock, &mut buyer_ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_config_for_testing(config);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_INVOICE_UNPAID)]
    fun unpaid_invoice_cannot_release_deposit() {
        let mut ctx = tx_context::dummy();
        let invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x2, 100, &mut ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(&invoice, @0x0, 25, 100, 0, &mut ctx);

        receivable_escrow::release_deposit(escrow, &invoice, &mut ctx);

        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_NOT_DEPOSITOR)]
    fun only_depositor_can_release() {
        let mut owner_ctx = tx_context::new_from_hint(@0x0, 20, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x0, 21, 0, 0, 0);
        let mut stranger_ctx = tx_context::new_from_hint(@0x0, 22, 0, 0, 0);
        let mut invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x0, 100, &mut owner_ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(&invoice, @0x1, 25, 100, 0, &mut owner_ctx);
        let payment = coin::mint_for_testing<SUI>(100, &mut payer_ctx);

        receivable::pay_invoice(&mut invoice, payment, &mut payer_ctx);
        receivable_escrow::release_deposit(escrow, &invoice, &mut stranger_ctx);

        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_WRONG_INVOICE)]
    fun deposit_cannot_be_released_against_another_invoice() {
        let mut ctx = tx_context::dummy();
        let invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x0, 100, &mut ctx);
        let other_invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x0, 100, &mut ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(&invoice, @0x0, 25, 100, 0, &mut ctx);

        receivable_escrow::release_deposit(escrow, &other_invoice, &mut ctx);

        receivable::destroy_for_testing(invoice);
        receivable::destroy_for_testing(other_invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_CLAIM_TOO_EARLY)]
    fun deposit_cannot_be_claimed_before_grace_period() {
        let mut ctx = tx_context::dummy();
        let invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x2, 100, &mut ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(&invoice, @0x0, 25, 100, 0, &mut ctx);
        let mut test_clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut test_clock, 1100);

        receivable_escrow::claim_deposit(escrow, &invoice, &test_clock, &mut ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_NOT_BENEFICIARY)]
    fun only_payment_recipient_can_claim_defaulted_deposit() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x0, 30, 0, 0, 0);
        let mut stranger_ctx = tx_context::new_from_hint(@0x0, 31, 0, 0, 0);
        let invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x3, 100, &mut issuer_ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(&invoice, @0x3, 25, 100, 0, &mut issuer_ctx);
        let mut test_clock = clock::create_for_testing(&mut issuer_ctx);
        clock::set_for_testing(&mut test_clock, 1101);

        receivable_escrow::claim_deposit(escrow, &invoice, &test_clock, &mut stranger_ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_INVOICE_PAID)]
    fun paid_invoice_deposit_cannot_be_claimed() {
        let mut ctx = tx_context::dummy();
        let mut invoice = receivable::invoice_for_testing<SUI>(@0x0, @0x0, 100, &mut ctx);
        let escrow = receivable_escrow::escrow_for_testing<SUI>(&invoice, @0x0, 25, 100, 0, &mut ctx);
        let payment = coin::mint_for_testing<SUI>(100, &mut ctx);
        let mut test_clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut test_clock, 1101);

        receivable::pay_invoice(&mut invoice, payment, &mut ctx);
        receivable_escrow::claim_deposit(escrow, &invoice, &test_clock, &mut ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    fun confirmed_delivery_releases_full_payment_and_settles_invoice() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 40, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x2, 41, 0, 0, 0);
        let mut invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let mut escrow = receivable_escrow::settlement_for_testing<SUI>(
            &invoice,
            @0x2,
            100,
            false,
            2000,
            0,
            &mut payer_ctx,
        );
        let mut test_clock = clock::create_for_testing(&mut issuer_ctx);
        clock::set_for_testing(&mut test_clock, 500);
        assert!(tx_context::sender(&payer_ctx) == @0x2, 100);
        assert!(receivable_escrow::settlement_payer(&escrow) == @0x2, 101);

        receivable_escrow::confirm_delivery(
            &mut escrow,
            &invoice,
            string::utf8(b"walrus-delivery-proof"),
            &mut payer_ctx,
        );
        assert!(receivable_escrow::delivery_confirmed(&escrow), 0);

        let mut releaser_ctx = tx_context::new_from_hint(@0x9, 42, 0, 0, 0);
        receivable_escrow::release_settlement(escrow, &mut invoice, &test_clock, &mut releaser_ctx);
        assert!(receivable::is_paid(&invoice), 1);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    fun unconfirmed_settlement_refunds_payer_after_deadline() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 50, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x2, 51, 0, 0, 0);
        let invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let escrow = receivable_escrow::settlement_for_testing<SUI>(
            &invoice,
            @0x2,
            100,
            false,
            1000,
            0,
            &mut payer_ctx,
        );
        let mut test_clock = clock::create_for_testing(&mut issuer_ctx);
        clock::set_for_testing(&mut test_clock, 1001);

        receivable_escrow::refund_settlement(escrow, &invoice, &test_clock, &mut payer_ctx);
        assert!(!receivable::is_paid(&invoice), 0);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_INCORRECT_SETTLEMENT_AMOUNT)]
    fun settlement_requires_exact_invoice_amount() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 60, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x2, 61, 0, 0, 0);
        let invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let payment = coin::mint_for_testing<SUI>(99, &mut payer_ctx);
        let test_clock = clock::create_for_testing(&mut issuer_ctx);

        receivable_escrow::escrow_payment(&invoice, payment, 1000, &test_clock, &mut payer_ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_NOT_PAYER)]
    fun only_invoice_payer_can_escrow_payment() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 70, 0, 0, 0);
        let mut stranger_ctx = tx_context::new_from_hint(@0x3, 71, 0, 0, 0);
        let invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let payment = coin::mint_for_testing<SUI>(100, &mut stranger_ctx);
        let test_clock = clock::create_for_testing(&mut issuer_ctx);

        receivable_escrow::escrow_payment(&invoice, payment, 1000, &test_clock, &mut stranger_ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_NOT_PAYER)]
    fun only_payer_can_confirm_delivery() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 80, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x2, 81, 0, 0, 0);
        let mut stranger_ctx = tx_context::new_from_hint(@0x3, 82, 0, 0, 0);
        let invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let mut escrow = receivable_escrow::settlement_for_testing<SUI>(
            &invoice,
            @0x2,
            100,
            false,
            2000,
            0,
            &mut payer_ctx,
        );

        receivable_escrow::confirm_delivery(
            &mut escrow,
            &invoice,
            string::utf8(b"walrus-delivery-proof"),
            &mut stranger_ctx,
        );

        receivable_escrow::destroy_settlement_for_testing(escrow);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_DELIVERY_NOT_CONFIRMED)]
    fun settlement_cannot_release_before_delivery_confirmation() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 90, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x2, 91, 0, 0, 0);
        let mut invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let escrow = receivable_escrow::settlement_for_testing<SUI>(
            &invoice,
            @0x2,
            100,
            false,
            2000,
            0,
            &mut payer_ctx,
        );
        let test_clock = clock::create_for_testing(&mut issuer_ctx);

        receivable_escrow::release_settlement(escrow, &mut invoice, &test_clock, &mut issuer_ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_REFUND_TOO_EARLY)]
    fun payer_cannot_refund_before_deadline() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 100, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x2, 101, 0, 0, 0);
        let invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let escrow = receivable_escrow::settlement_for_testing<SUI>(
            &invoice,
            @0x2,
            100,
            false,
            2000,
            0,
            &mut payer_ctx,
        );
        let mut test_clock = clock::create_for_testing(&mut issuer_ctx);
        clock::set_for_testing(&mut test_clock, 2000);

        receivable_escrow::refund_settlement(escrow, &invoice, &test_clock, &mut payer_ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }

    #[test]
    #[expected_failure(abort_code = receivable_escrow::E_DELIVERY_CONFIRMED)]
    fun confirmed_settlement_cannot_be_refunded() {
        let mut issuer_ctx = tx_context::new_from_hint(@0x1, 110, 0, 0, 0);
        let mut payer_ctx = tx_context::new_from_hint(@0x2, 111, 0, 0, 0);
        let invoice = receivable::invoice_for_testing<SUI>(@0x1, @0x2, 100, &mut issuer_ctx);
        let escrow = receivable_escrow::settlement_for_testing<SUI>(
            &invoice,
            @0x2,
            100,
            true,
            1000,
            0,
            &mut payer_ctx,
        );
        let mut test_clock = clock::create_for_testing(&mut issuer_ctx);
        clock::set_for_testing(&mut test_clock, 1001);

        receivable_escrow::refund_settlement(escrow, &invoice, &test_clock, &mut payer_ctx);

        clock::destroy_for_testing(test_clock);
        receivable::destroy_for_testing(invoice);
    }
}
