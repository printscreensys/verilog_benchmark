from cocotb_coverage.coverage import CoverPoint, coverage_db


SCENARIO_BINS = [
    "push_into_empty",
    "push_into_mid",
    "push_into_full_overflow",
    "pop_from_empty_underflow",
    "pop_from_mid",
    "pop_from_full",
    "push_pop_on_empty",
    "push_pop_on_mid",
    "push_pop_on_full",
    "flush_empty",
    "flush_nonempty",
]

LIMIT_BINS = [1, 2, 3, 4]


@CoverPoint("cdv.scenario", xf=lambda event: event["scenario"], bins=SCENARIO_BINS)
@CoverPoint("cdv.limit", xf=lambda event: event["limit"], bins=LIMIT_BINS)
def sample_event(event):
    return event


def export_coverage(path):
    coverage_db.export_to_yaml(path)
