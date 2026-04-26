from cocotb_coverage.coverage import CoverPoint, coverage_db


OBJECTIVE_BINS = [
    "module_named_top_dec",
    "three_pipeline_stages",
    "stage1_registers_directional_inputs",
    "valid_enable_zero_mux_after_stage1",
    "route_computation_uses_rc_for_four_ports",
    "permutation_network_before_stage2",
    "stage2_registers_permutation_local_bypass",
    "req_vector_combines_bypass_and_four_pv_fields",
    "valid_vector_combines_bypass_and_four_valids",
    "port_alloc_parallel_used",
    "local_block_prepares_crossbar_inputs",
    "xbar5ports_switch_traversal",
    "pv_bypass_priority_indices",
    "stage3_registers_all_outputs",
    "output_muxes_zero_invalid_outputs",
]


@CoverPoint("cdv.objectives", xf=lambda event: event["objective"], bins=OBJECTIVE_BINS)
def sample_event(event):
    return event


def export_coverage(path):
    coverage_db.export_to_yaml(path)
