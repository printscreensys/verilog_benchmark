from cocotb_coverage.coverage import CoverPoint, coverage_db


OBJECTIVE_BINS = [
    "module_named_alloc_two",
    "input_ready_from_not_fifo_full",
    "fifo_write_on_valid_and_not_full",
    "route_id_extracted_from_rtid_bits",
    "route_id_split_into_x_y",
    "left_routes_greater_y_to_a_equal_y_to_b",
    "right_routes_less_y_to_a_equal_y_to_b",
    "up_routes_greater_x_to_a_equal_x_to_b",
    "down_routes_less_x_to_a_equal_x_to_b",
    "route_choice_latches_after_first_fire",
    "tail_fire_releases_packet_state",
    "fifo_ready_uses_selected_output_ready",
    "outputs_mirror_fifo_data",
]


@CoverPoint("cdv.objectives", xf=lambda event: event["objective"], bins=OBJECTIVE_BINS)
def sample_event(event):
    return event


def export_coverage(path):
    coverage_db.export_to_yaml(path)
