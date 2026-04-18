import math
from typing import List, Tuple

def pass_at_k(n: int, c: int, k: int) -> float:
    if c == 0:
        return 0.0
    if k > n:
        return 1.0
    return 1 - (math.comb(n - c, k) / math.comb(n, k))


def mean_pass_at_k(problems: List[Tuple[int, int]], k: int) -> float:
    """
    Compute average pass@k across multiple problems.

    Args:
        problems: list of (n, c) tuples per problem
        k: number of attempts

    Returns:
        float: mean pass@k
    """
    if not problems:
        return 0.0

    total = 0.0
    for n, c in problems:
        total += pass_at_k(n, c, k)

    return total / len(problems)