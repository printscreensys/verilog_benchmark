from cocotb_coverage.coverage import CoverPoint, coverage_db


OBJECTIVE_BINS = [
    "module_named_bch_sigma_bma_serial",
    "serial_berlekamp_massey_algorithm",
    "includes_bch_vh_and_macro_parameter_widths",
    "computes_sigma_error_locator",
    "uses_syndromes_and_syn1",
    "start_sets_busy_and_initializes_state",
    "done_asserts_on_final_calculation",
    "ack_done_clears_done",
    "ready_requires_not_busy_and_done_ack",
    "uses_bch_n_and_inner_count_counters",
    "cycle_markers_first_second_penult_last",
    "bsel_depends_on_nonzero_discrepancy_and_error_count",
    "err_count_updates_when_bsel",
    "beta_updates_from_sigma_last_or_shifted_beta",
    "uses_finite_field_divider_multiplier_adder_helpers",
]


@CoverPoint("cdv.objectives", xf=lambda event: event["objective"], bins=OBJECTIVE_BINS)
def sample_event(event):
    return event


def export_coverage(path):
    coverage_db.export_to_yaml(path)
