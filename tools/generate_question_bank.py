import json
import random
import re
from pathlib import Path

RNG = random.Random(20261017)
QUESTIONS = []
EXPOSURE_TIMER_SCALES = {"GREEN": 1.0, "YELLOW": 0.92, "ORANGE": 0.82, "RED": 0.72, "CRITICAL": 0.58}


def question_base_time(question):
    tier = int(question["difficulty"])
    category = question["category"]
    sub = question["subcategory"]
    formulas = {
        "arithmetic": {"addition_subtraction": 12, "order_of_operations": 15, "parentheses": 16,
                       "division_subtraction": 14, "mixed_operations": 17, "percentages": 13,
                       "parentheses_and_order": 19, "powers_and_products": 18, "nested_operations": 20,
                       "boss_nested_expression": 34},
        "patterns": {"constant_difference": 12, "changing_differences": 17, "interleaved_sequences": 19,
                     "square_numbers": 13, "recursive_rule": 17, "composite_rule": 19,
                     "boss_polynomial": 35, "boss_interleaved": 38},
        "logic": {"ordering": 16, "constraint_algebra": 20, "truth_table": 19, "consistency_check": 16},
        "memory": {"position_recall": 11, "reverse_recall": 14, "count_recall": 13,
                   "edge_recall": 12, "adjacency_recall": 13},
        "attention": {"number_classification": 12, "string_comparison": 11, "sequence_comparison": 11},
    }
    base = formulas.get(category, {}).get(sub, 14) + tier * 2.1
    if category == "memory":
        base += len(str(question.get("stimulus", "")).split()) * 0.45
    if category == "attention":
        base += len(re.findall(r"\d+|[A-Z]{2,}", str(question.get("prompt", "")))) * 0.35
    return int(max(10, min(42, round(base))))


def make_timer_table(base_seconds):
    return {band: max(6, round(base_seconds * scale)) for band, scale in EXPOSURE_TIMER_SCALES.items()}


def build_intel_hint(question):
    category = question["category"]
    sub = question["subcategory"]
    prompt = question["prompt"]
    if category == "arithmetic":
        first_step = str(question.get("explanation", "")).split(";")[0].strip().rstrip(".")
        if first_step:
            return f"First step: {first_step}. Use that intermediate value to finish the expression."
        hints = {
            "addition_subtraction": "Work left to right, then check the size of your result against both starting values.",
            "order_of_operations": "Do the multiplication first; the final addition is a separate step.",
            "parentheses": "Treat the sum inside parentheses as one value before multiplying.",
            "division_subtraction": "Find the exact quotient first, then subtract the final value.",
            "mixed_operations": "Multiplication and division have equal priority; evaluate them left to right before addition.",
            "percentages": "Convert the percentage to a fraction over 100, then simplify before multiplying.",
            "parentheses_and_order": "Finish the parenthesized sum, multiply that result, and only then subtract.",
            "powers_and_products": "Evaluate the square and the product before combining the two results.",
            "nested_operations": "Resolve the multiplication inside the parentheses before the outer division.",
            "boss_nested_expression": "There are two separate products: finish the parenthesized one, divide it, then add the second product.",
        }
        return hints.get(sub, question.get("hint", "Break the expression into ordered steps."))
    if category == "patterns":
        values = [int(value) for value in re.findall(r"-?\d+", prompt)]
        gaps = [values[i+1] - values[i] for i in range(len(values)-1)]
        if len(gaps) >= 3:
            return "The visible step sizes are " + ", ".join(f"{gap:+d}" for gap in gaps) + ". Compare the step sizes with each other."
        return question.get("hint", "Check whether the sequence alternates or uses a repeating operation.")
    if category == "logic":
        if sub == "constraint_algebra":
            match = re.search(r"total duration (\d+) minutes", prompt)
            total = int(match.group(1)) if match else 0
            return f"The three durations can be written x, x + 7, and x + 16. Their sum is {total}."
        if sub == "ordering":
            return "The clues form one forced chain. Link each 'before' statement and count positions from the start."
        if sub == "truth_table":
            return "Test each room separately. Count duplicate statements independently when checking 'exactly one'."
        return "Apply both rules to the named packet; one rule requires a state the other forbids."
    if category == "memory":
        sequence = str(question.get("stimulus", "")).split()
        if not sequence:
            return "The sequence is stored for this hint. Use the requested positions and keep their order straight."
        if sub == "position_recall":
            match = re.search(r"position (\d+)", prompt)
            pos = int(match.group(1))-1 if match else 0
            neighbor_positions = [i for i in (pos-1, pos+1) if 0 <= i < len(sequence)]
            return "Useful landmarks: " + "; ".join(f"position {i+1} was {sequence[i]}" for i in neighbor_positions) + "."
        if sub == "reverse_recall":
            return f"The original sequence began {sequence[0]}, {sequence[1]} and ended {sequence[-2]}, {sequence[-1]}; reverse both order and direction."
        if sub == "count_recall":
            target_match = re.search(r"did (\w+) appear", prompt)
            target = target_match.group(1) if target_match else "the target"
            positions = [index + 1 for index, symbol in enumerate(sequence) if symbol == target]
            half = "first" if positions and positions[0] <= len(sequence) / 2 else "second"
            return f"The sequence has {len(sequence)} positions. {target} appears in the {half} half; scan each position once and keep the two halves separate."
        if sub == "edge_recall":
            return f"One edge is confirmed: the first symbol was {sequence[0]}. Recall the final symbol separately."
        match = re.search(r"after position (\d+)", prompt)
        pos = int(match.group(1))-1 if match else 0
        before = sequence[pos-1] if pos > 0 else sequence[0]
        return f"Position {pos+1} contained {before}; the question asks for the symbol immediately after it."
    if category == "attention":
        if sub == "number_classification":
            exception_match = re.search(r"(\d+) is not a perfect square", str(question.get("explanation", "")))
            exception = exception_match.group(1) if exception_match else "the outlier"
            return f"Check {exception} by comparing it with the squares immediately below and above it, then locate it in the list."
        if sub == "string_comparison":
            pair = re.search(r": ([A-Z]+) / ([A-Z]+)$", prompt)
            if pair:
                left, right = pair.group(1), pair.group(2)
                prefix = 0
                while prefix < len(left) and left[prefix] == right[prefix]:
                    prefix += 1
                suffix = 0
                while suffix < len(left)-prefix and left[-1-suffix] == right[-1-suffix]:
                    suffix += 1
                return f"The strings share {prefix} character(s) at the start and {suffix} at the end; inspect the positions between those matching sections."
            return "The strings have equal length and exactly one changed character. Compare aligned positions from the left."
        pair = re.search(r"(\d+) → (\d+)", prompt)
        if pair:
            changed_from, changed_to = pair.group(1), pair.group(2)
            old_digits, new_digits = list(changed_from), list(changed_to)
            change = next((f"{old}→{new}" for old, new in zip(old_digits, new_digits) if old != new), "one digit")
            return f"The changed digit is {change}; use its position in the aligned sequences as your answer."
        return "The sequences differ at one index only. Align the digits and check each index in order."
    return question.get("hint", "Break the challenge into smaller steps.")


def add(category, subcategory, tier, prompt, answer, explanation, hint, seconds=None, **extra):
    index = 1 + sum(q["category"] == category for q in QUESTIONS)
    q = {
        "id": f"{category[:3].upper()}_{index:03d}",
        "category": category,
        "subcategory": subcategory,
        "difficulty": tier,
        "type": "numeric_input" if isinstance(answer, (int, float)) else "text_input",
        "prompt": prompt,
        "answer": answer,
        "accepted_answers": [answer],
        "time_limit_seconds": seconds or (18 - tier),
        "base_points": 100 + (tier - 1) * 25,
        "credit_reward": 20 + tier * 5,
        "explanation": explanation,
        "hint": hint,
        "tags": [category, subcategory],
        "validated": True,
        "boss_eligible": False,
    }
    q.update(extra)
    green_time = question_base_time(q)
    q["time_limits_by_exposure"] = make_timer_table(green_time)
    if q["boss_eligible"]:
        q["boss_time_limits_by_exposure"] = make_timer_table(min(48, max(green_time + 10, round(green_time * 1.35))))
    q["time_limit_seconds"] = green_time
    q["intel_hint"] = build_intel_hint(q)
    QUESTIONS.append(q)


# Arithmetic: 100 varied items, including genuinely multi-operation tier 4/5 work.
for i in range(100):
    tier = i % 5 + 1
    n = i
    kind = (i // 5) % 10
    if kind == 0:
        a = 137 + n * 17 + tier * 9
        b = 86 + (n * 13) % 211
        c = 29 + (n * 7) % 83
        ans = a + b - c
        prompt = f"Calculate {a} + {b} - {c}."
        exp = f"Add the first two numbers to get {a+b}; then subtract {c} to reach the total."
        sub = "addition_subtraction"
    elif kind == 1:
        a = 18 + (n * 7) % 43
        b = 13 + (n * 11) % 37
        c = 4 + n % 9
        ans = a * b + c
        prompt = f"Calculate {a} × {b} + {c}."
        exp = f"Multiply first: {a} × {b} = {a*b}; then add {c} to get {ans}."
        sub = "order_of_operations"
    elif kind == 2:
        a = 7 + (n * 3) % 19
        b = 5 + (n * 5) % 17
        c = 3 + n % 8
        ans = a * (b + c)
        prompt = f"Calculate {a} × ({b} + {c})."
        exp = f"Evaluate the parentheses first: {b}+{c}={b+c}; then {a}×{b+c}={ans}."
        sub = "parentheses"
    elif kind == 3:
        d = 3 + n % 9
        q = 17 + n * 3 + tier
        a = d * q
        b = 11 + n % 21
        ans = a // d - b
        prompt = f"Calculate {a} ÷ {d} - {b}."
        exp = f"Divide first: {a}÷{d}={q}; then subtract {b} to get {ans}."
        sub = "division_subtraction"
    elif kind == 4:
        d = 3 + n % 8
        q = 9 + n * 2 + tier
        a = d * q
        b = 4 + n % 13
        ans = a // d + b * 2
        prompt = f"Calculate {a} ÷ {d} + {b} × 2."
        exp = f"Do division and multiplication first: {q}+{b*2}={ans}."
        sub = "mixed_operations"
    elif kind == 5:
        pct = [15, 12, 35, 18, 22][tier-1]
        base = 200 + n * 20
        # Chosen bases make every percentage result integral.
        base = base // 100 * 100
        ans = base * pct // 100
        prompt = f"What is {pct}% of {base}?"
        exp = f"{pct}% is {pct}/100; {base}×{pct}/100={ans}."
        sub = "percentages"
    elif kind == 6:
        a = 3 + n % 11
        b = 4 + (n * 3) % 13
        c = 2 + n % 7
        d = 5 + n % 9
        ans = (a + b) * c - d
        prompt = f"Calculate ({a} + {b}) × {c} - {d}."
        exp = f"Parentheses: {a+b}; multiply: {(a+b)*c}; subtract {d}: {ans}."
        sub = "parentheses_and_order"
    elif kind == 7:
        a = 2 + n % 8
        b = 5 + n % 9
        c = 3 + (n * 2) % 7
        ans = a * a + b * c
        prompt = f"Calculate {a}² + {b} × {c}."
        exp = f"Evaluate the power and product first: {a*a}+{b*c}={ans}."
        sub = "powers_and_products"
    elif kind == 8:
        a = 120 + n * 8
        b = 12 + n % 15
        c = 3 + n % 6
        ans = (a - b * c) // 2
        prompt = f"Calculate ({a} - {b} × {c}) ÷ 2."
        exp = f"Multiply first: {b}×{c}={b*c}; subtract from {a}, then halve to get {ans}."
        sub = "nested_operations"
    else:
        c = 2 + n % 6
        a = c * (12 + n % 20)
        b = 6 + n % 9
        ans = a * b // c + (n % 13)
        prompt = f"Calculate {a} × {b} ÷ {c} + {n%13}."
        exp = f"Multiply and divide left to right: {a}×{b}÷{c}={a*b//c}; add {n%13} to get {ans}."
        sub = "mixed_operations"
    add("arithmetic", sub, tier, prompt, ans, exp,
        "Use order of operations: parentheses, powers, multiplication/division, then addition/subtraction.",
        20 if tier >= 4 else 16)


# Patterns: each tier has different rule families and longer/more layered sequences.
for i in range(60):
    tier = i % 5 + 1
    n = i
    kind = n % 6
    if kind == 0:
        start = 11 + n * 2
        step = 3 + (n * 5) % 17
        seq = [start + j * step for j in range(5)]
        ans = seq[-1] + step
        rule, sub = f"Each term increases by {step}.", "constant_difference"
    elif kind == 1:
        start = 4 + n
        step = 2 + n % 8
        seq = [start]
        for j in range(1, 5):
            seq.append(seq[-1] + step + 2 * (j - 1))
        ans = seq[-1] + step + 8
        rule, sub = "The gaps increase by 2 each time.", "changing_differences"
    elif kind == 2:
        a, b = 3 + n, 8 + 2 * n
        da, db = 2 + n % 5, 3 + n % 7
        seq = [a, b, a+da, b+db, a+2*da, b+2*db]
        ans = b + 3 * db
        rule, sub = f"Read odd and even positions separately: their steps are +{da} and +{db}.", "interleaved_sequences"
    elif kind == 3:
        base = 2 + n % 17
        seq = [(base+j)**2 for j in range(5)]
        ans = (base+5)**2
        rule, sub = "These are consecutive square numbers.", "square_numbers"
    elif kind == 4:
        a, b = 2 + n % 8, 3 + n % 7
        seq = [a, b]
        for _ in range(4):
            seq.append(seq[-1] + seq[-2] + (n % 3))
        ans = seq[-1] + seq[-2] + (n % 3)
        rule, sub = f"Each term is the previous two added together, with {n%3} added.", "recursive_rule"
    else:
        start = 5 + n
        seq = [start]
        for j in range(1, 6):
            seq.append(seq[-1] * 2 + j + tier)
        ans = seq[-1] * 2 + 6 + tier
        rule, sub = f"Double each term, then add 1, 2, 3, 4, 5, 6 in order (with tier offset {tier}).", "composite_rule"
    add("patterns", sub, tier, f"What comes next? {', '.join(map(str, seq))}, ?", ans,
        f"{rule} The next value is {ans}.", "Compare the differences first; if they do not fit, test alternating positions or a recursive rule.", 20)


# Logic: varied deduction, scheduling, truth, and set reasoning with explicit unique answers.
for i in range(60):
    tier = i % 5 + 1
    n = i
    if n % 4 == 0:
        people = ["Ari", "Bo", "Cy", "Dee", "Eli"]
        rotation = n % len(people)
        p = people[rotation:] + people[:rotation]
        # Chain forces the final item; ask for the position of the named item.
        prompt = f"Case {n+1}: Five jobs are run in order. {p[0]} is before {p[1]}, {p[1]} before {p[2]}, {p[2]} before {p[3]}, and {p[3]} before {p[4]}. What position is {p[2]}?"
        ans = "3"
        exp = f"The clues force {p[0]}, {p[1]}, {p[2]}, {p[3]}, {p[4]} in that order, so {p[2]} is third."
        sub = "ordering"
    elif n % 4 == 1:
        x = 14 + n
        y = x + 7
        z = y + 9
        prompt = f"Three consecutive system checks have total duration {x+y+z} minutes. The second takes 7 minutes longer than the first; the third takes 9 minutes longer than the second. How long is the first?"
        ans = str(x)
        exp = f"Let the first be x: x+(x+7)+(x+16)={x+y+z}, so x={x} minutes."
        sub = "constraint_algebra"
    elif n % 4 == 2:
        rooms = ["NORTH", "EAST", "SOUTH"]
        target = rooms[n % 3]
        other = [r for r in rooms if r != target]
        prompt = f"Case {n+1}: A key is in NORTH, EAST, or SOUTH. Exactly one statement is true: (1) it is in {target}; (2) it is in {other[0]}; (3) it is in {other[0]}. Which room contains it?"
        ans = target
        exp = f"Testing the three locations against the exactly-one-true condition leaves {target} as the only solution."
        sub = "truth_table"
    else:
        count = 4 + n % 5
        prompt = f"Every encrypted packet is logged. No unverified packet is logged. Packet P{n} is encrypted but unverified. Can all three statements be true together? Answer Yes or No."
        ans = "No"
        exp = "An encrypted packet must be logged, while an unverified packet cannot be logged. P is both, so the statements conflict."
        sub = "consistency_check"
    add("logic", sub, tier, prompt, ans, exp,
        "Translate each clue into a constraint, then eliminate any candidate that breaks one.", 22)


# Memory: mixed recall tasks; stimulus is hidden before the answer prompt appears.
SYMBOLS = ["TRIANGLE", "CIRCLE", "SQUARE", "DIAMOND", "STAR", "HEXAGON", "CROSS", "ARROW", "MOON", "WAVE"]
for i in range(50):
    tier = i % 5 + 1
    n = i // 5
    mode = n % 5
    length = 4 + tier + n % 2
    seq = [SYMBOLS[(n * 3 + j * (1 + n % 4)) % len(SYMBOLS)] for j in range(length)]
    if len(set(seq)) < len(seq):
        seq = RNG.sample(SYMBOLS, length)
    stimulus = "   ".join(seq)
    if mode == 0:
        pos = (n * 3 + tier) % length
        response, answer = f"Which symbol was in position {pos+1}?", seq[pos]
        exp = f"Position {pos+1} contained {answer}."
        sub = "position_recall"
    elif mode == 1:
        response, answer = "Enter the symbols in reverse order, separated by spaces.", " ".join(reversed(seq))
        exp = f"Reversing the sequence gives {answer}."
        sub = "reverse_recall"
    elif mode == 2:
        target = seq[n % length]
        response, answer = f"How many times did {target} appear? Enter a number.", str(seq.count(target))
        exp = f"{target} appeared {answer} time(s)."
        sub = "count_recall"
    elif mode == 3:
        response, answer = "Enter the first and last symbols separated by | (example: STAR|MOON).", seq[0] + "|" + seq[-1]
        exp = f"The first and last symbols were {seq[0]} and {seq[-1]}."
        sub = "edge_recall"
    else:
        pos = (n + 2) % (length - 1)
        response, answer = f"What symbol came immediately after position {pos+1}?", seq[pos+1]
        exp = f"The symbol after position {pos+1} was {answer}."
        sub = "adjacency_recall"
    add("memory", sub, tier, response, answer, exp,
        "Track the requested position or relationship from the start of the sequence; use the hint for a remembered landmark.", 20,
        stimulus=stimulus, response_prompt=response, display_duration_seconds=max(1.8, 4.0-tier*0.35))


# Attention: distinct comparison and classification tasks at progressively larger sizes.
for i in range(50):
    tier = i % 5 + 1
    n = i // 5
    length = 5 + tier + n % 3
    if n % 3 == 0:
        base = 12 + n
        squares = [(base+j) ** 2 for j in range(length-1)]
        odd = base * base + 2
        vals = squares + [odd]
        RNG.shuffle(vals)
        pos = vals.index(odd) + 1
        prompt = "All but one value are consecutive perfect squares. Enter the position of the exception: " + ", ".join(map(str, vals))
        answer = str(pos)
        exp = f"{odd} is not a perfect square; it appears in position {pos}."
        sub = "number_classification"
    elif n % 3 == 1:
        alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        left = "".join(alphabet[(n*3+j*5) % len(alphabet)] for j in range(length))
        pos0 = (n*2 + tier) % length
        right = left[:pos0] + alphabet[(alphabet.index(left[pos0])+3) % len(alphabet)] + left[pos0+1:]
        prompt = f"These strings differ in exactly one position. Enter it (count from 1): {left} / {right}"
        answer = str(pos0+1)
        exp = f"The differing character is at position {pos0+1}."
        sub = "string_comparison"
    else:
        digits = [str((n*3+j*7) % 10) for j in range(length)]
        pos0 = (n+tier) % length
        changed = digits.copy()
        changed[pos0] = str((int(changed[pos0])+5) % 10)
        prompt = f"Which index changed? Count from 1. {''.join(digits)} → {''.join(changed)}"
        answer = str(pos0+1)
        exp = f"Only index {pos0+1} changed."
        sub = "sequence_comparison"
    add("attention", sub, tier, prompt, answer, exp,
        "Compare one position at a time from left to right.", 18)


# Dedicated boss pool: multi-stage expressions and layered sequences only.
for i in range(26):
    a = 45 + 5 * i
    b = 27 + 3 * i
    c = 4 + 2 * (i % 4)
    d = 8 + 2 * (i % 6)
    f = 13 + 4 * i
    g = 3 + i % 5
    answer = ((a + b) * c - d) // 2 + f * g
    prompt = f"Calculate (({a} + {b}) × {c} - {d}) ÷ 2 + {f} × {g}."
    explanation = f"Parentheses: {a+b}; first product: {(a+b)*c}; subtract {d} and halve to get {((a+b)*c-d)//2}; second product: {f*g}; total: {answer}."
    add("arithmetic", "boss_nested_expression", 5, prompt, answer, explanation,
        "There are two separate products: finish the parenthesized one, divide it, then add the second product.",
        42, boss_eligible=True, tags=["arithmetic", "boss", "order_of_operations"])

for i in range(14):
    if i % 2 == 0:
        start = 1 + i
        sequence = [n**3 + 2*n**2 + 3*n + start for n in range(1, 6)]
        answer = 6**3 + 2*6**2 + 3*6 + start
        rule = "The first differences are not constant; the second differences grow in a regular pattern."
        sub = "boss_polynomial"
    else:
        multiplier = 3 + (i % 3)
        odd_terms = [2 * multiplier**n for n in range(4)]
        even_start = 5 + i
        even_step = 7 + i
        even_terms = [even_start + n*even_step for n in range(4)]
        sequence = [odd_terms[0], even_terms[0], odd_terms[1], even_terms[1], odd_terms[2], even_terms[2], odd_terms[3]]
        answer = even_terms[3]
        rule = f"Separate odd and even positions: odd terms multiply by {multiplier}; even terms increase by {even_step}."
        sub = "boss_interleaved"
    prompt = f"Find the next number and identify the rule: {', '.join(map(str, sequence))}, ?"
    add("patterns", sub, 5, prompt, answer,
        f"{rule} The next term is {answer}.",
        "Separate the odd and even positions, or compare the first and second differences before extending the sequence.",
        42, boss_eligible=True, rule_description=rule, tags=["patterns", "boss", sub])


assert len(QUESTIONS) == 360, len(QUESTIONS)
assert len({q["id"] for q in QUESTIONS}) == len(QUESTIONS)
prompts = [q["prompt"] + str(q.get("stimulus", "")) for q in QUESTIONS]
if len(set(prompts)) != len(QUESTIONS):
    print("Duplicate prompts:", [p for p in set(prompts) if prompts.count(p) > 1])
assert len(set(prompts)) == len(QUESTIONS)
assert all(q["answer"] in q["accepted_answers"] and q["validated"] for q in QUESTIONS)
assert all(sum(q["category"] == c for q in QUESTIONS) >= 50 for c in ("arithmetic", "patterns", "logic", "memory", "attention"))
assert all(set(q["time_limits_by_exposure"]) == {"GREEN", "YELLOW", "ORANGE", "RED", "CRITICAL"} for q in QUESTIONS)
assert all(q.get("intel_hint", "").strip() for q in QUESTIONS)
boss_questions = [q for q in QUESTIONS if q["boss_eligible"]]
assert len(boss_questions) == 40
assert all(q["difficulty"] == 5 and q["subcategory"].startswith("boss_") for q in boss_questions)
assert all(set(q["boss_time_limits_by_exposure"]) == {"GREEN", "YELLOW", "ORANGE", "RED", "CRITICAL"} for q in boss_questions)
output = Path(__file__).resolve().parents[1] / "data" / "question_bank.json"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps({"schema_version": 2, "question_count": len(QUESTIONS), "questions": QUESTIONS}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Wrote {len(QUESTIONS)} questions")
