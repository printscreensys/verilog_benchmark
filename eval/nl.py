import json


def evaluate_description(response_file, rubric_file):
    with open(response_file, "r", encoding="utf-8") as handle:
        response = handle.read()
    with open(rubric_file, "r", encoding="utf-8") as handle:
        rubric = json.load(handle)

    normalized = response.lower().replace("_", "")
    passed = []
    missing = []

    for concept in rubric.get("concepts", []):
        name = str(concept["name"])
        keywords = [
            str(keyword).lower().replace("_", "")
            for keyword in concept.get("keywords", [])
        ]
        if any(keyword in normalized for keyword in keywords):
            passed.append(name)
        else:
            missing.append(name)

    score = len(passed)
    total = len(rubric.get("concepts", []))
    passing_score = int(rubric.get("passing_score", total))
    benchmark_pass = score >= passing_score
    return {
        "description_score": score,
        "description_total": total,
        "description_passed": benchmark_pass,
        "benchmark_pass": benchmark_pass,
        "passed_concepts": passed,
        "missing_concepts": missing,
    }
