from test_support import contains, observe, observe_if


def run_sequences():
    observe("module_named_top_dec", evidence="module top_dec")
    observe_if("stage1_registers_directional_inputs", contains("pipeline_reg_1", "dinW", "dinE", "dinS", "dinN"))
    observe_if("route_computation_uses_rc_for_four_ports", contains("routeCompNorth", "routeCompEast", "routeCompSouth", "routeCompWest"))
