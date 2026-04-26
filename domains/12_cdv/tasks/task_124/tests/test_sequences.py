from test_support import contains, observe, observe_if


def run_sequences():
    observe("module_named_smii_txrx", evidence="module smii_txrx")
    observe_if("uses_state_1_to_10_schedule", contains("state", "1:10"))
    observe_if("tx_toggles_a0_between_low_and_high_nibble", contains("a0", "mtxd"))
