from cocotb_coverage.coverage import CoverPoint, coverage_db


OBJECTIVE_BINS = [
    "module_named_smii_txrx",
    "bridges_smii_serial_and_mii_nibbles",
    "uses_state_1_to_10_schedule",
    "slow_speed_counts_0_to_9",
    "speed_high_bypasses_slow_counter",
    "tx_packs_two_mii_nibbles_into_byte",
    "tx_toggles_a0_between_low_and_high_nibble",
    "tx_serializes_error_speed_duplex_link_jabber_status",
    "rx_shifts_serial_bits_into_rx_tmp",
    "rx_unpacks_nibbles_to_mrxd_and_mrxdv",
    "rx_status_states_update_error_speed_duplex_link_jabber",
    "mii_tx_and_rx_clocks_generated_from_states",
    "collision_is_mcrs_and_mtxen",
]


@CoverPoint("cdv.objectives", xf=lambda event: event["objective"], bins=OBJECTIVE_BINS)
def sample_event(event):
    return event


def export_coverage(path):
    coverage_db.export_to_yaml(path)
