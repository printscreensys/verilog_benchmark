import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from .common import clean_tool_output


DEFAULT_OPENSTA_IMAGE = "opensta_ubuntu22.04"
DEFAULT_YOSYS_CANDIDATES = (
    "/usr/local/bin/oss-cad-suite/bin/yosys",
    "/opt/oss-cad-suite/bin/yosys",
)
OPENSTA_CONTAINER_BINARY = "/OpenSTA/build/sta"


def _load_timing_spec(timing_spec_file):
    with open(timing_spec_file, "r", encoding="utf-8") as handle:
        spec = json.load(handle)

    required_fields = [
        "top_module",
        "clock_period_ns",
        "max_comb_depth_units",
    ]
    missing_fields = [field for field in required_fields if field not in spec]
    if missing_fields:
        raise ValueError(
            "Timing spec is missing required fields: " + ", ".join(missing_fields)
        )

    clock_period_ns = float(spec["clock_period_ns"])
    max_comb_depth_units = int(spec["max_comb_depth_units"])
    surrogate_unit_ns = float(spec.get("surrogate_unit_ns", 1.0))

    if clock_period_ns <= 0.0:
        raise ValueError("clock_period_ns must be positive.")
    if max_comb_depth_units <= 0:
        raise ValueError("max_comb_depth_units must be positive.")
    if surrogate_unit_ns <= 0.0:
        raise ValueError("surrogate_unit_ns must be positive.")

    max_register_bits = spec.get("max_register_bits")
    if max_register_bits is not None:
        max_register_bits = int(max_register_bits)
        if max_register_bits <= 0:
            raise ValueError("max_register_bits must be positive when provided.")

    opensta_input_delay_ns = float(spec.get("opensta_input_delay_ns", 0.0))
    opensta_output_delay_ns = float(spec.get("opensta_output_delay_ns", 0.0))
    if opensta_input_delay_ns < 0.0:
        raise ValueError("opensta_input_delay_ns must be non-negative when provided.")
    if opensta_output_delay_ns < 0.0:
        raise ValueError("opensta_output_delay_ns must be non-negative when provided.")

    return {
        "top_module": spec["top_module"],
        "clock_period_ns": clock_period_ns,
        "max_comb_depth_units": max_comb_depth_units,
        "surrogate_unit_ns": surrogate_unit_ns,
        "max_register_bits": max_register_bits,
        "clock_port": spec.get("clock_port", "clk"),
        "opensta_docker_image": spec.get("opensta_docker_image", DEFAULT_OPENSTA_IMAGE),
        "opensta_liberty_file": spec.get("opensta_liberty_file"),
        "opensta_input_delay_ns": opensta_input_delay_ns,
        "opensta_output_delay_ns": opensta_output_delay_ns,
    }


def _strip_verilog_comments(text):
    without_block_comments = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//.*", "", without_block_comments)


def _base_signal_name(signal_name):
    match = re.match(r"\s*([$A-Za-z_][$\w]*)", signal_name or "")
    return match.group(1) if match else None


def _split_top_level(text, delimiter):
    parts = []
    current = []
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0

    for char in text:
        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth = max(0, paren_depth - 1)
        elif char == "[":
            bracket_depth += 1
        elif char == "]":
            bracket_depth = max(0, bracket_depth - 1)
        elif char == "{":
            brace_depth += 1
        elif char == "}":
            brace_depth = max(0, brace_depth - 1)

        if (
            char == delimiter
            and paren_depth == 0
            and bracket_depth == 0
            and brace_depth == 0
        ):
            parts.append("".join(current).strip())
            current = []
            continue

        current.append(char)

    if current:
        parts.append("".join(current).strip())

    return [part for part in parts if part]


def _extract_module_source(verilog_text, top_module):
    module_match = re.search(rf"\bmodule\s+{re.escape(top_module)}\b", verilog_text)
    if module_match is None:
        raise ValueError(f"Top module '{top_module}' was not found in the Verilog source.")

    end_match = re.search(r"\bendmodule\b", verilog_text[module_match.start():])
    if end_match is None:
        raise ValueError(f"Module '{top_module}' is missing an endmodule terminator.")

    module_end = module_match.start() + end_match.end()
    return verilog_text[module_match.start():module_end]


def _extract_header_port_info(module_text):
    module_name_match = re.search(r"\bmodule\s+[$A-Za-z_][$\w]*\s*\(", module_text)
    if module_name_match is None:
        return {}

    header_start = module_name_match.end() - 1
    cursor = header_start
    paren_depth = 0

    while cursor < len(module_text):
        char = module_text[cursor]
        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth -= 1
            if paren_depth == 0:
                break
        cursor += 1

    if paren_depth != 0:
        return {}

    port_blob = module_text[header_start + 1:cursor]
    ports = {}

    for segment in _split_top_level(port_blob, ","):
        if not re.search(r"\b(input|output|inout)\b", segment):
            continue

        width = 1
        width_match = re.search(r"\[\s*(\d+)\s*:\s*(\d+)\s*\]", segment)
        if width_match:
            msb = int(width_match.group(1))
            lsb = int(width_match.group(2))
            width = abs(msb - lsb) + 1

        direction_match = re.search(r"\b(input|output|inout)\b", segment)
        name_match = re.search(r"([$A-Za-z_][$\w]*)\s*$", segment)

        if direction_match and name_match:
            ports[name_match.group(1)] = {
                "direction": direction_match.group(1),
                "width": width,
            }

    return ports


def _extract_module_port_names(module_text):
    module_name_match = re.search(r"\bmodule\s+[$A-Za-z_][$\w]*\s*\(", module_text)
    if module_name_match is None:
        return []

    header_start = module_name_match.end() - 1
    cursor = header_start
    paren_depth = 0

    while cursor < len(module_text):
        char = module_text[cursor]
        if char == "(":
            paren_depth += 1
        elif char == ")":
            paren_depth -= 1
            if paren_depth == 0:
                break
        cursor += 1

    if paren_depth != 0:
        return []

    port_blob = module_text[header_start + 1:cursor]
    port_names = []
    for segment in _split_top_level(port_blob, ","):
        port_name = _base_signal_name(segment)
        if port_name:
            port_names.append(port_name)
    return port_names


def _extract_body_port_info(module_text, module_port_names):
    port_name_set = set(module_port_names)
    if not port_name_set:
        return {}

    ports = {}
    header_end = module_text.find(");")
    body_text = module_text[header_end + 2:] if header_end != -1 else module_text
    declaration_pattern = re.compile(
        r"\b(input|output|inout)\b\s*(?:reg|wire|logic\s*)?(?:signed\s*)?"
        r"(?:\[(\d+)\s*:\s*(\d+)\])?\s*([^;]+);",
        re.S,
    )

    for direction, msb_text, lsb_text, names_blob in declaration_pattern.findall(body_text):
        width = 1
        if msb_text and lsb_text:
            width = abs(int(msb_text) - int(lsb_text)) + 1

        for raw_name in _split_top_level(names_blob, ","):
            name = _base_signal_name(raw_name)
            if name and name in port_name_set:
                ports[name] = {
                    "direction": direction,
                    "width": width,
                }

    return ports


def _extract_body_declared_widths(module_text):
    widths = {}
    header_end = module_text.find(");")
    body_text = module_text[header_end + 2:] if header_end != -1 else module_text

    declaration_pattern = re.compile(
        r"\b(?:reg|wire|logic|integer)\b\s*(?:signed\s*)?(?:\[(\d+)\s*:\s*(\d+)\])?\s*([^;]+);",
        re.S,
    )
    for match in declaration_pattern.finditer(body_text):
        msb_text, lsb_text, names_blob = match.groups()
        width = 1
        if msb_text is not None and lsb_text is not None:
            width = abs(int(msb_text) - int(lsb_text)) + 1

        for raw_name in _split_top_level(names_blob, ","):
            name = _base_signal_name(raw_name)
            if name:
                widths[name] = width

    return widths


def _collect_continuous_assignments(module_text):
    assignments = {}
    assign_pattern = re.compile(r"\bassign\s+(.+?)=\s*(.+?);", re.S)
    for match in assign_pattern.finditer(module_text):
        lhs = _base_signal_name(match.group(1))
        rhs = match.group(2).strip()
        if lhs:
            assignments[lhs] = rhs
    return assignments


def _extract_always_blocks(module_text):
    blocks = []
    always_pattern = re.compile(r"\balways\b")

    for match in always_pattern.finditer(module_text):
        cursor = match.end()
        while cursor < len(module_text) and module_text[cursor].isspace():
            cursor += 1

        if cursor >= len(module_text) or module_text[cursor] != "@":
            continue

        sensitivity_start = cursor
        cursor += 1
        while cursor < len(module_text) and module_text[cursor].isspace():
            cursor += 1

        if cursor < len(module_text) and module_text[cursor] == "(":
            paren_depth = 1
            cursor += 1
            while cursor < len(module_text) and paren_depth > 0:
                if module_text[cursor] == "(":
                    paren_depth += 1
                elif module_text[cursor] == ")":
                    paren_depth -= 1
                cursor += 1
        elif cursor < len(module_text) and module_text[cursor] == "*":
            cursor += 1
        else:
            continue

        sensitivity = module_text[sensitivity_start:cursor]

        while cursor < len(module_text) and module_text[cursor].isspace():
            cursor += 1

        if module_text[cursor:cursor + 5] == "begin":
            block_start = cursor + 5
            block_cursor = block_start
            block_depth = 1

            while block_cursor < len(module_text) and block_depth > 0:
                keyword_match = re.search(r"\b(begin|end)\b", module_text[block_cursor:])
                if keyword_match is None:
                    raise ValueError("Unterminated begin/end block while parsing always block.")

                block_cursor += keyword_match.start()
                keyword = keyword_match.group(1)
                if keyword == "begin":
                    block_depth += 1
                else:
                    block_depth -= 1
                block_cursor += len(keyword)

            body = module_text[block_start:block_cursor - 3]
            blocks.append({"sensitivity": sensitivity, "body": body})
            continue

        statement_end = module_text.find(";", cursor)
        if statement_end == -1:
            raise ValueError("Could not find the end of an always statement.")

        body = module_text[cursor:statement_end + 1]
        blocks.append({"sensitivity": sensitivity, "body": body})

    return blocks


def _collect_sequential_assignments(module_text):
    assignments = []
    sequential_regs = set()
    assignment_pattern = re.compile(
        r"([$A-Za-z_][$\w]*(?:\s*\[[^\]]+\])?)\s*(<=|=)\s*(.+?);",
        re.S,
    )

    for block in _extract_always_blocks(module_text):
        sensitivity = block["sensitivity"]
        if "posedge" not in sensitivity and "negedge" not in sensitivity:
            continue

        for lhs_text, _operator, rhs in assignment_pattern.findall(block["body"]):
            lhs = _base_signal_name(lhs_text)
            if lhs:
                assignments.append((lhs, rhs.strip()))
                sequential_regs.add(lhs)

    return assignments, sequential_regs


def _tokenize_expression(expression_text):
    tokens = []
    cursor = 0
    multi_char_ops = [
        "<<<",
        ">>>",
        "===",
        "!==",
        "<<",
        ">>",
        "<=",
        ">=",
        "==",
        "!=",
        "&&",
        "||",
        "^~",
        "~^",
    ]
    number_pattern = re.compile(
        r"(?:\d+'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+|\d+|'[01xXzZ])"
    )

    while cursor < len(expression_text):
        char = expression_text[cursor]

        if char.isspace():
            cursor += 1
            continue

        number_match = number_pattern.match(expression_text, cursor)
        if number_match:
            tokens.append(number_match.group(0))
            cursor = number_match.end()
            continue

        matched_op = None
        for operator in multi_char_ops:
            if expression_text.startswith(operator, cursor):
                matched_op = operator
                break
        if matched_op is not None:
            tokens.append(matched_op)
            cursor += len(matched_op)
            continue

        if char in "(){}?:,+-*/%&|^~!<>":
            tokens.append(char)
            cursor += 1
            continue

        if char in "$_" or char.isalpha():
            start = cursor
            cursor += 1
            while cursor < len(expression_text) and (
                expression_text[cursor] == "$"
                or expression_text[cursor] == "_"
                or expression_text[cursor].isalnum()
            ):
                cursor += 1

            while True:
                lookahead = cursor
                while lookahead < len(expression_text) and expression_text[lookahead].isspace():
                    lookahead += 1

                if lookahead >= len(expression_text) or expression_text[lookahead] != "[":
                    break

                bracket_depth = 1
                lookahead += 1
                while lookahead < len(expression_text) and bracket_depth > 0:
                    if expression_text[lookahead] == "[":
                        bracket_depth += 1
                    elif expression_text[lookahead] == "]":
                        bracket_depth -= 1
                    lookahead += 1
                cursor = lookahead

            tokens.append(expression_text[start:cursor])
            continue

        tokens.append(char)
        cursor += 1

    return tokens


class _ExpressionDepthParser:
    OPERATOR_WEIGHTS = {
        "*": 4,
        "/": 4,
        "%": 4,
        "+": 2,
        "-": 2,
        "<<": 1,
        ">>": 1,
        "<<<": 1,
        ">>>": 1,
        "&": 1,
        "|": 1,
        "^": 1,
        "^~": 1,
        "~^": 1,
        "&&": 1,
        "||": 1,
        "==": 1,
        "!=": 1,
        "===": 1,
        "!==": 1,
        "<": 1,
        "<=": 1,
        ">": 1,
        ">=": 1,
        "?:": 1,
        "unary": 1,
        "concat": 1,
        "call": 0,
    }

    def __init__(self, tokens, signal_depth_resolver):
        self.tokens = tokens
        self.signal_depth_resolver = signal_depth_resolver
        self.position = 0

    def _peek(self):
        if self.position >= len(self.tokens):
            return None
        return self.tokens[self.position]

    def _peek_next(self):
        if self.position + 1 >= len(self.tokens):
            return None
        return self.tokens[self.position + 1]

    def _consume(self, expected=None):
        token = self._peek()
        if token is None:
            raise ValueError("Unexpected end of expression while parsing timing surrogate.")
        if expected is not None and token != expected:
            raise ValueError(f"Expected token '{expected}', found '{token}'.")
        self.position += 1
        return token

    def parse(self):
        depth = self._parse_conditional()
        if self._peek() is not None:
            raise ValueError(f"Unexpected token '{self._peek()}' in expression.")
        return depth

    def _parse_conditional(self):
        condition_depth = self._parse_logical_or()
        if self._peek() != "?":
            return condition_depth
        self._consume("?")
        true_depth = self._parse_conditional()
        self._consume(":")
        false_depth = self._parse_conditional()
        return max(condition_depth, true_depth, false_depth) + self.OPERATOR_WEIGHTS["?:"]

    def _parse_logical_or(self):
        return self._parse_binary_chain(self._parse_logical_and, {"||"})

    def _parse_logical_and(self):
        return self._parse_binary_chain(self._parse_bitwise_or, {"&&"})

    def _parse_bitwise_or(self):
        return self._parse_binary_chain(self._parse_bitwise_xor, {"|"})

    def _parse_bitwise_xor(self):
        return self._parse_binary_chain(self._parse_bitwise_and, {"^", "^~", "~^"})

    def _parse_bitwise_and(self):
        return self._parse_binary_chain(self._parse_equality, {"&"})

    def _parse_equality(self):
        return self._parse_binary_chain(self._parse_relational, {"==", "!=", "===", "!=="})

    def _parse_relational(self):
        return self._parse_binary_chain(self._parse_shift, {"<", "<=", ">", ">="})

    def _parse_shift(self):
        return self._parse_binary_chain(self._parse_additive, {"<<", ">>", "<<<", ">>>"})

    def _parse_additive(self):
        return self._parse_binary_chain(self._parse_multiplicative, {"+", "-"})

    def _parse_multiplicative(self):
        return self._parse_binary_chain(self._parse_unary, {"*", "/", "%"})

    def _parse_binary_chain(self, next_parser, operators):
        depth = next_parser()
        while self._peek() in operators:
            operator = self._consume()
            rhs_depth = next_parser()
            depth = max(depth, rhs_depth) + self.OPERATOR_WEIGHTS[operator]
        return depth

    def _parse_unary(self):
        if self._peek() in {"+", "-", "!", "~", "&", "|", "^", "^~", "~^"}:
            self._consume()
            return self._parse_unary() + self.OPERATOR_WEIGHTS["unary"]
        return self._parse_primary()

    def _parse_primary(self):
        token = self._peek()
        if token is None:
            raise ValueError("Unexpected end of expression.")

        if token == "(":
            self._consume("(")
            depth = self._parse_conditional()
            self._consume(")")
            return depth

        if token == "{":
            return self._parse_concatenation()

        if re.fullmatch(r"(?:\d+'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+|\d+|'[01xXzZ])", token):
            self._consume()
            return 0

        if re.fullmatch(r"[$A-Za-z_][$\w]*(?:\s*\[[^\]]+\])*", token):
            identifier = self._consume()
            if self._peek() == "(":
                return self._parse_call(identifier)
            base_name = _base_signal_name(identifier)
            return self.signal_depth_resolver(base_name)

        self._consume()
        return 0

    def _parse_call(self, identifier):
        self._consume("(")
        argument_depths = []
        if self._peek() != ")":
            while True:
                argument_depths.append(self._parse_conditional())
                if self._peek() != ",":
                    break
                self._consume(",")
        self._consume(")")
        return max(argument_depths or [0]) + self.OPERATOR_WEIGHTS["call"]

    def _parse_concatenation(self):
        self._consume("{")

        if self._peek() is not None and re.fullmatch(r"(?:\d+|'[01xXzZ])", self._peek() or ""):
            replication_count = self._peek()
            if self._peek_next() == "{":
                self._consume(replication_count)
                depth = self._parse_concatenation()
                self._consume("}")
                return depth + self.OPERATOR_WEIGHTS["concat"]

        item_depths = []
        while self._peek() is not None and self._peek() != "}":
            item_depths.append(self._parse_conditional())
            if self._peek() == ",":
                self._consume(",")
                continue
            break

        self._consume("}")
        return max(item_depths or [0]) + self.OPERATOR_WEIGHTS["concat"]


def _estimate_expression_depth(expression_text, signal_depth_resolver):
    tokens = _tokenize_expression(expression_text)
    if not tokens:
        return 0
    parser = _ExpressionDepthParser(tokens, signal_depth_resolver)
    return parser.parse()


def _build_base_timing_metrics():
    return {
        "timing_check_ran": False,
        "timing_constraints_met": None,
        "timing_message": "",
        "timing_analysis_method": "",
        "clock_period_ns": None,
        "estimated_critical_path_units": None,
        "estimated_critical_path_ns": None,
        "timing_slack_ns": None,
        "max_comb_depth_units": None,
        "register_bits": None,
        "max_register_bits": None,
        "area_constraints_met": None,
        "constraint_score": None,
        "opensta_image": None,
        "opensta_image_available": None,
        "opensta_message": "",
    }


def _analyze_verilog_structure(verilog_file, timing_spec):
    with open(verilog_file, "r", encoding="utf-8") as handle:
        verilog_text = handle.read()

    module_text = _extract_module_source(
        _strip_verilog_comments(verilog_text),
        timing_spec["top_module"],
    )
    module_port_names = _extract_module_port_names(module_text)
    header_ports = _extract_header_port_info(module_text)
    body_ports = _extract_body_port_info(module_text, module_port_names)
    ports = dict(header_ports)
    ports.update(body_ports)
    body_widths = _extract_body_declared_widths(module_text)
    signal_widths = {
        name: port_info["width"]
        for name, port_info in ports.items()
    }
    signal_widths.update(body_widths)

    continuous_assignments = _collect_continuous_assignments(module_text)
    sequential_assignments, sequential_regs = _collect_sequential_assignments(module_text)
    output_ports = {
        name
        for name, port_info in ports.items()
        if port_info["direction"] == "output"
    }

    register_bits = 0
    for register_name in sequential_regs:
        register_bits += int(signal_widths.get(register_name, 1))

    return {
        "module_text": module_text,
        "header_ports": ports,
        "module_port_names": module_port_names,
        "signal_widths": signal_widths,
        "continuous_assignments": continuous_assignments,
        "sequential_assignments": sequential_assignments,
        "sequential_regs": sequential_regs,
        "output_ports": output_ports,
        "register_bits": register_bits,
    }


def _run_surrogate_timing_check(verilog_file, timing_spec_file, timing_spec):
    result_metrics = _build_base_timing_metrics()

    structure = _analyze_verilog_structure(verilog_file, timing_spec)
    continuous_assignments = structure["continuous_assignments"]
    sequential_assignments = structure["sequential_assignments"]
    sequential_regs = structure["sequential_regs"]
    output_ports = structure["output_ports"]
    register_bits = structure["register_bits"]

    depth_cache = {}
    active_signals = set()

    def resolve_signal_depth(signal_name):
        if signal_name is None:
            return 0
        if signal_name in sequential_regs:
            return 0
        if signal_name in depth_cache:
            return depth_cache[signal_name]
        if signal_name not in continuous_assignments:
            return 0
        if signal_name in active_signals:
            raise ValueError(f"Combinational loop detected around '{signal_name}'.")

        active_signals.add(signal_name)
        depth = _estimate_expression_depth(
            continuous_assignments[signal_name],
            resolve_signal_depth,
        )
        active_signals.remove(signal_name)
        depth_cache[signal_name] = depth
        return depth

    critical_path_units = 0
    path_targets = []
    for lhs, rhs in sequential_assignments:
        depth_units = _estimate_expression_depth(rhs, resolve_signal_depth)
        critical_path_units = max(critical_path_units, depth_units)
        path_targets.append((lhs, depth_units))

    for output_name in sorted(output_ports):
        if output_name in sequential_regs or output_name not in continuous_assignments:
            continue
        depth_units = resolve_signal_depth(output_name)
        critical_path_units = max(critical_path_units, depth_units)
        path_targets.append((output_name, depth_units))

    estimated_critical_path_ns = round(
        critical_path_units * timing_spec["surrogate_unit_ns"],
        3,
    )
    timing_slack_ns = round(
        timing_spec["clock_period_ns"] - estimated_critical_path_ns,
        3,
    )
    timing_constraints_met = critical_path_units <= timing_spec["max_comb_depth_units"]

    max_register_bits = timing_spec["max_register_bits"]
    area_constraints_met = True
    if max_register_bits is not None:
        area_constraints_met = register_bits <= max_register_bits

    timing_efficiency = min(
        1.0,
        timing_spec["clock_period_ns"] / max(estimated_critical_path_ns, 1e-9),
    )
    if max_register_bits is None:
        area_efficiency = 1.0
    else:
        area_efficiency = min(1.0, max_register_bits / max(register_bits, 1))

    collapsed_paths = {}
    for target, depth_units in path_targets:
        collapsed_paths[target] = max(depth_units, collapsed_paths.get(target, 0))

    constraint_score = round(
        max(0.0, min(1.0, (timing_efficiency * 0.7) + (area_efficiency * 0.3))),
        3,
    )

    result_metrics.update(
        {
            "timing_check_ran": True,
            "timing_constraints_met": timing_constraints_met and area_constraints_met,
            "timing_message": "Timing surrogate analysis completed.",
            "timing_analysis_method": "surrogate_depth_model",
            "clock_period_ns": timing_spec["clock_period_ns"],
            "estimated_critical_path_units": critical_path_units,
            "estimated_critical_path_ns": estimated_critical_path_ns,
            "timing_slack_ns": timing_slack_ns,
            "max_comb_depth_units": timing_spec["max_comb_depth_units"],
            "register_bits": register_bits,
            "max_register_bits": max_register_bits,
            "area_constraints_met": area_constraints_met,
            "constraint_score": constraint_score,
            "timing_paths": [
                {
                    "target": target,
                    "depth_units": depth_units,
                }
                for target, depth_units in sorted(
                    collapsed_paths.items(),
                    key=lambda item: item[1],
                    reverse=True,
                )
            ],
        }
    )

    return result_metrics


def _run_command(command, *, cwd=None, timeout=60):
    process = subprocess.run(
        command,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    output = clean_tool_output(process.stdout + process.stderr)
    return process.returncode, output


def _resolve_yosys_binary():
    configured = os.environ.get("YOSYS_BIN")
    if configured:
        candidate = Path(configured)
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)

    discovered = shutil.which("yosys")
    if discovered is not None:
        return discovered

    for candidate_path in DEFAULT_YOSYS_CANDIDATES:
        candidate = Path(candidate_path)
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)

    return None


def _docker_image_available(image_name):
    if shutil.which("docker") is None:
        return False, "Docker is not installed."

    try:
        returncode, output = _run_command(
            ["docker", "image", "inspect", image_name],
            timeout=20,
        )
    except Exception as exc:
        return False, f"Docker image inspection failed: {str(exc)}"

    if returncode == 0:
        return True, "Docker image is available."

    if output:
        return False, output
    return False, f"Docker image '{image_name}' was not found."


def _docker_image_has_command(image_name, command_name):
    try:
        returncode, output = _run_command(
            [
                "docker",
                "run",
                "--rm",
                image_name,
                "sh",
                "-lc",
                f"command -v {command_name}",
            ],
            timeout=30,
        )
    except Exception as exc:
        return False, f"Failed to probe '{command_name}' in Docker image: {str(exc)}"

    if returncode == 0:
        return True, output
    return False, output or f"Command '{command_name}' was not found in Docker image."


def _docker_container_available(container_name):
    try:
        returncode, output = _run_command(
            [
                "docker",
                "container",
                "inspect",
                "-f",
                "{{.State.Running}}",
                container_name,
            ],
            timeout=20,
        )
    except Exception as exc:
        return False, f"Docker container inspection failed: {str(exc)}"

    if returncode == 0 and output.strip().lower() == "true":
        return True, "Docker container is available."

    if output:
        return False, output
    return False, f"Docker container '{container_name}' was not found."


def _resolve_opensta_liberty_file(timing_spec, timing_spec_file):
    configured_liberty = timing_spec.get("opensta_liberty_file")
    if configured_liberty:
        candidate = Path(configured_liberty)
        if not candidate.is_absolute():
            candidate = Path(timing_spec_file).resolve().parent / candidate
        return candidate if candidate.exists() else None

    task_dir = Path(timing_spec_file).resolve().parent
    liberty_candidates = sorted(task_dir.glob("*.lib")) + sorted(task_dir.glob("*.liberty"))
    if len(liberty_candidates) == 1:
        return liberty_candidates[0]
    return None


def _extract_opensta_slack(report_text):
    patterns = [
        r"(-?\d+(?:\.\d+)?)\s+slack\s+\((?:MET|VIOLATED)\)",
        r"slack\s+\((?:MET|VIOLATED)\)\s+(-?\d+(?:\.\d+)?)",
        r"slack\s+(-?\d+(?:\.\d+)?)",
    ]
    for pattern in patterns:
        match = re.search(pattern, report_text)
        if match is not None:
            return float(match.group(1))
    return None


def _build_yosys_script(top_module_name):
    return "\n".join(
        [
            "read_verilog design.v",
            f"hierarchy -check -top {top_module_name}",
            "proc",
            "opt",
            "fsm",
            "opt",
            "memory",
            "opt",
            "techmap",
            "opt",
            "dfflibmap -liberty library.lib",
            "abc -liberty library.lib",
            "clean",
            "write_verilog -noattr netlist.v",
        ]
    )


def _build_opensta_script(timing_spec, file_prefix=""):
    def prefixed(name):
        if not file_prefix:
            return name
        return f"{file_prefix.rstrip('/')}/{name}"

    lines = [
        f"read_liberty {prefixed('library.lib')}",
        f"read_verilog {prefixed('netlist.v')}",
        f"link_design {timing_spec['top_module']}",
        (
            f"create_clock -name bench_clk -period {timing_spec['clock_period_ns']} "
            f"[get_ports {timing_spec['clock_port']}]"
        ),
    ]

    if timing_spec["opensta_input_delay_ns"] > 0.0:
        lines.append(
            "set_input_delay "
            f"{timing_spec['opensta_input_delay_ns']} -clock bench_clk "
            f"[remove_from_collection [all_inputs] [get_ports {timing_spec['clock_port']}]]"
        )
    if timing_spec["opensta_output_delay_ns"] > 0.0:
        lines.append(
            f"set_output_delay {timing_spec['opensta_output_delay_ns']} -clock bench_clk [all_outputs]"
        )

    lines.extend(
        [
            "report_checks -path_delay max -digits 4",
            "exit",
        ]
    )
    return "\n".join(lines)


def _run_yosys_synthesis(work_dir, image_name):
    host_yosys = _resolve_yosys_binary()
    if host_yosys is not None:
        return _run_command(
            [host_yosys, "-q", "-s", "synth.ys"],
            cwd=work_dir,
            timeout=120,
        )

    has_yosys, message = _docker_image_has_command(image_name, "yosys")
    if not has_yosys:
        return 1, message

    return _run_command(
        [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{work_dir}:/work",
            "-w",
            "/work",
            image_name,
            "yosys",
            "-q",
            "-s",
            "synth.ys",
        ],
        timeout=240,
    )


def _run_opensta_in_docker(work_dir, image_name):
    return _run_command(
        [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{work_dir}:/work",
            image_name,
            "/work/timing.tcl",
        ],
        timeout=240,
    )


def _run_opensta_in_container(work_dir, container_name):
    return _run_command(
        [
            "docker",
            "exec",
            container_name,
            OPENSTA_CONTAINER_BINARY,
            f"{work_dir}/timing.tcl",
        ],
        timeout=240,
    )


def _run_opensta_timing_check(verilog_file, timing_spec_file, timing_spec):
    result_metrics = _build_base_timing_metrics()
    result_metrics["opensta_image"] = timing_spec["opensta_docker_image"]

    image_available, image_message = _docker_image_available(timing_spec["opensta_docker_image"])
    result_metrics["opensta_image_available"] = image_available
    result_metrics["opensta_message"] = image_message
    if not image_available:
        return result_metrics

    liberty_file = _resolve_opensta_liberty_file(timing_spec, timing_spec_file)
    if liberty_file is None:
        result_metrics["opensta_message"] = (
            "OpenSTA image is available, but no Liberty file was provided or discovered."
        )
        return result_metrics

    structure = _analyze_verilog_structure(verilog_file, timing_spec)
    register_bits = structure["register_bits"]
    header_ports = structure["header_ports"]

    if timing_spec["clock_port"] not in header_ports:
        result_metrics["opensta_message"] = (
            f"Clock port '{timing_spec['clock_port']}' was not found in top module "
            f"'{timing_spec['top_module']}'."
        )
        return result_metrics

    max_register_bits = timing_spec["max_register_bits"]
    area_constraints_met = True
    if max_register_bits is not None:
        area_constraints_met = register_bits <= max_register_bits

    with tempfile.TemporaryDirectory(prefix="opensta_eval_") as temp_dir:
        work_dir = Path(temp_dir)
        shutil.copyfile(verilog_file, work_dir / "design.v")
        shutil.copyfile(liberty_file, work_dir / "library.lib")
        (work_dir / "synth.ys").write_text(
            _build_yosys_script(timing_spec["top_module"]),
            encoding="utf-8",
        )
        opensta_container_name = os.environ.get("OPENSTA_DOCKER_CONTAINER", "").strip()
        use_opensta_container = False
        if opensta_container_name:
            use_opensta_container, _ = _docker_container_available(opensta_container_name)
        (work_dir / "timing.tcl").write_text(
            _build_opensta_script(
                timing_spec,
                str(work_dir) if use_opensta_container else "/work",
            ),
            encoding="utf-8",
        )

        synth_returncode, synth_output = _run_yosys_synthesis(
            str(work_dir),
            timing_spec["opensta_docker_image"],
        )
        if synth_returncode != 0:
            result_metrics["opensta_message"] = (
                "OpenSTA image is available, but synthesis for timing failed: "
                + synth_output
            )
            return result_metrics

        if use_opensta_container:
            sta_returncode, sta_output = _run_opensta_in_container(
                str(work_dir),
                opensta_container_name,
            )
        else:
            sta_returncode, sta_output = _run_opensta_in_docker(
                str(work_dir),
                timing_spec["opensta_docker_image"],
            )
        if sta_returncode != 0:
            result_metrics["opensta_message"] = (
                "OpenSTA execution failed: " + sta_output
            )
            return result_metrics

        slack_ns = _extract_opensta_slack(sta_output)
        if slack_ns is None:
            result_metrics["opensta_message"] = (
                "OpenSTA ran, but worst slack could not be parsed from the report."
            )
            return result_metrics

        estimated_critical_path_ns = round(
            timing_spec["clock_period_ns"] - slack_ns,
            3,
        )
        timing_efficiency = min(
            1.0,
            timing_spec["clock_period_ns"] / max(estimated_critical_path_ns, 1e-9),
        )
        if max_register_bits is None:
            area_efficiency = 1.0
        else:
            area_efficiency = min(1.0, max_register_bits / max(register_bits, 1))

        constraint_score = round(
            max(0.0, min(1.0, (timing_efficiency * 0.7) + (area_efficiency * 0.3))),
            3,
        )

        result_metrics.update(
            {
                "timing_check_ran": True,
                "timing_constraints_met": (slack_ns >= 0.0) and area_constraints_met,
                "timing_message": "OpenSTA timing analysis completed.",
                "timing_analysis_method": "opensta_docker",
                "clock_period_ns": timing_spec["clock_period_ns"],
                "estimated_critical_path_ns": estimated_critical_path_ns,
                "timing_slack_ns": round(slack_ns, 3),
                "max_comb_depth_units": timing_spec["max_comb_depth_units"],
                "register_bits": register_bits,
                "max_register_bits": max_register_bits,
                "area_constraints_met": area_constraints_met,
                "constraint_score": constraint_score,
                "opensta_message": sta_output,
            }
        )

    return result_metrics


def run_optional_timing_check(verilog_file, timing_spec_file):
    result_metrics = {
        "timing_check_ran": False,
        "timing_constraints_met": None,
        "timing_message": "",
        "timing_analysis_method": "",
        "clock_period_ns": None,
        "estimated_critical_path_units": None,
        "estimated_critical_path_ns": None,
        "timing_slack_ns": None,
        "max_comb_depth_units": None,
        "register_bits": None,
        "max_register_bits": None,
        "area_constraints_met": None,
        "constraint_score": None,
        "opensta_image": None,
        "opensta_image_available": None,
        "opensta_message": "",
    }

    if timing_spec_file is None:
        result_metrics["timing_message"] = "Skipped: no timing specification was provided."
        return result_metrics

    try:
        timing_spec = _load_timing_spec(timing_spec_file)
        opensta_results = _run_opensta_timing_check(
            verilog_file,
            timing_spec_file,
            timing_spec,
        )
        if opensta_results["timing_analysis_method"] == "opensta_docker":
            return opensta_results

        surrogate_results = _run_surrogate_timing_check(
            verilog_file,
            timing_spec_file,
            timing_spec,
        )
        surrogate_results["opensta_image"] = opensta_results["opensta_image"]
        surrogate_results["opensta_image_available"] = opensta_results["opensta_image_available"]
        surrogate_results["opensta_message"] = opensta_results["opensta_message"]
        if opensta_results["opensta_message"]:
            surrogate_results["timing_message"] = (
                opensta_results["opensta_message"]
                + " Falling back to surrogate timing analysis."
            )
        return surrogate_results
    except Exception as exc:
        result_metrics["timing_check_ran"] = True
        result_metrics["timing_constraints_met"] = False
        result_metrics["timing_message"] = f"Timing analysis error: {str(exc)}"

    return result_metrics
