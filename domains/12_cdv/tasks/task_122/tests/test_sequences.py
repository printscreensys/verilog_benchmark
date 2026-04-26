from test_support import contains, observe, observe_if


def run_sequences():
    observe("module_named_alloc_two", evidence="module alloc_two")
    observe_if("input_ready_from_not_fifo_full", contains("ready_o", "fifo_full"))
    observe_if("fifo_write_on_valid_and_not_full", contains("fifo_wr", "valid_i", "fifo_full"))
