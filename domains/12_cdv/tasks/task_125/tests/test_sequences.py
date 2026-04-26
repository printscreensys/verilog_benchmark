from test_support import contains, observe, observe_if


def run_sequences():
    observe("module_named_bch_sigma_bma_serial", evidence="module bch_sigma_bma_serial")
    observe_if("uses_syndromes_and_syn1", contains("syndromes", "syn1"))
    observe_if("ready_requires_not_busy_and_done_ack", contains("ready", "busy", "ack_done"))
