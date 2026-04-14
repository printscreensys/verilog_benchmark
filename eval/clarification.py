import json
import re


def _normalize_text(text):
    normalized = re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()
    return f" {normalized} " if normalized else " "


def _contains_phrase(haystack, phrase):
    needle = _normalize_text(phrase)
    return needle != " " and needle in haystack


def _extract_question_candidates(raw_questions):
    candidates = []
    for raw_line in raw_questions.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        line = re.sub(r"^\s*(?:[-*]|\d+[.)])\s*", "", line)
        for part in re.split(r"\?+", line):
            candidate = part.strip(" \t.:;,-")
            if candidate:
                candidates.append(candidate)
    return candidates


def _load_clarification_spec(clarification_spec_file):
    with open(clarification_spec_file, "r", encoding="utf-8") as handle:
        spec = json.load(handle)

    required_intents = spec.get("required_intents", [])
    if not required_intents:
        raise ValueError("Clarification spec must define at least one required intent.")

    for intent in required_intents:
        if "id" not in intent or "title" not in intent or "answer" not in intent:
            raise ValueError("Each required intent must contain id, title, and answer.")
        if not intent.get("match_all"):
            raise ValueError(f"Clarification intent '{intent['id']}' is missing match_all rules.")

    return spec


def _question_matches_intent(candidate, intent):
    candidate_normalized = _normalize_text(candidate)
    for group in intent.get("match_all", []):
        if not any(_contains_phrase(candidate_normalized, synonym) for synonym in group):
            return False
    return True


def _build_answer_bundle_text(clarification_spec, covered_intents):
    lines = []
    preamble = clarification_spec.get(
        "answer_preamble",
        "Append the following benchmark answers to the original prompt before RTL generation.",
    )
    if preamble:
        lines.append(preamble)

    if not covered_intents:
        lines.append("No clarification answers were released because no supported intents were matched.")
        return "\n".join(lines)

    for index, intent in enumerate(covered_intents, start=1):
        lines.append(f"{index}. {intent['title']}: {intent['answer']}")

    return "\n".join(lines)


def evaluate_clarification_questions(questions_file, clarification_spec_file):
    clarification_spec = _load_clarification_spec(clarification_spec_file)
    with open(questions_file, "r", encoding="utf-8") as handle:
        raw_questions = handle.read()

    question_candidates = _extract_question_candidates(raw_questions)
    required_intents = clarification_spec["required_intents"]
    intents_by_id = {intent["id"]: intent for intent in required_intents}

    covered_intent_ids = set()
    covered_intents_in_order = []
    matched_questions = []
    duplicate_questions = []
    unmatched_questions = []

    for question_index, candidate in enumerate(question_candidates, start=1):
        matched_intent_ids = [
            intent["id"]
            for intent in required_intents
            if _question_matches_intent(candidate, intent)
        ]
        new_intent_ids = [intent_id for intent_id in matched_intent_ids if intent_id not in covered_intent_ids]
        duplicate_intent_ids = [intent_id for intent_id in matched_intent_ids if intent_id in covered_intent_ids]

        if new_intent_ids:
            for intent_id in new_intent_ids:
                covered_intent_ids.add(intent_id)
                covered_intents_in_order.append(intents_by_id[intent_id])

            matched_questions.append(
                {
                    "question_index": question_index,
                    "question": candidate,
                    "matched_intents": new_intent_ids,
                    "duplicate_intents": duplicate_intent_ids,
                }
            )
            continue

        if matched_intent_ids:
            duplicate_questions.append(
                {
                    "question_index": question_index,
                    "question": candidate,
                    "matched_intents": matched_intent_ids,
                }
            )
            continue

        unmatched_questions.append(
            {
                "question_index": question_index,
                "question": candidate,
            }
        )

    required_intent_ids = [intent["id"] for intent in required_intents]
    missing_intent_ids = [intent_id for intent_id in required_intent_ids if intent_id not in covered_intent_ids]

    total_questions = len(question_candidates)
    matched_question_count = len(matched_questions)
    coverage_ratio = (
        len(covered_intent_ids) / len(required_intent_ids) if required_intent_ids else 1.0
    )
    precision_ratio = matched_question_count / total_questions if total_questions else 0.0
    max_reasonable_questions = clarification_spec.get(
        "max_reasonable_questions",
        len(required_intent_ids) + 2,
    )
    verbosity_penalty = 0.0
    if total_questions > max_reasonable_questions and max_reasonable_questions > 0:
        verbosity_penalty = (total_questions - max_reasonable_questions) / max_reasonable_questions

    clarification_score = max(
        0.0,
        min(1.0, (coverage_ratio * 0.85) + (precision_ratio * 0.15) - (verbosity_penalty * 0.10)),
    )
    answer_bundle_text = _build_answer_bundle_text(clarification_spec, covered_intents_in_order)

    return {
        "questions_file": questions_file,
        "clarification_spec_file": clarification_spec_file,
        "question_count": total_questions,
        "matched_question_count": matched_question_count,
        "unmatched_question_count": len(unmatched_questions),
        "duplicate_question_count": len(duplicate_questions),
        "required_intent_count": len(required_intent_ids),
        "covered_required_intent_count": len(covered_intent_ids),
        "required_intents_covered": covered_intent_ids == set(required_intent_ids),
        "coverage_ratio": round(coverage_ratio, 3),
        "precision_ratio": round(precision_ratio, 3),
        "clarification_score": round(clarification_score, 3),
        "matched_questions": matched_questions,
        "duplicate_questions": duplicate_questions,
        "unmatched_questions": unmatched_questions,
        "missing_required_intents": [
            {
                "id": intent["id"],
                "title": intent["title"],
                "question_intent": intent.get("question_intent", ""),
            }
            for intent in required_intents
            if intent["id"] in missing_intent_ids
        ],
        "provided_answers": [
            {
                "id": intent["id"],
                "title": intent["title"],
                "answer": intent["answer"],
            }
            for intent in covered_intents_in_order
        ],
        "answer_bundle": answer_bundle_text,
    }
