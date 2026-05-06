"""Benchmark local model categorization accuracy on mini_todo prompts.

Runs categorize() N times per prompt and scores against an expected
category. Designed to be invoked once per model via env override:

    BYLLM_DEFAULT_MODEL=local:gemma-4-e4b jac run bench_local.jac
"""

import os;
import from main { Category, categorize }

glob runs_per_prompt = 3,
     cases: list[tuple[str, Category]] = [
         ("Buy milk and bread", Category.SHOPPING),
         ("Submit Q2 expense report", Category.WORK),
         ("Schedule annual physical exam", Category.HEALTH),
         ("Plan weekend hike with friends", Category.PERSONAL),
         ("Wash the dishes after dinner", Category.PERSONAL),
         ("Order new running shoes online", Category.SHOPPING),
         ("Refill blood pressure prescription", Category.HEALTH),
         ("Prepare slides for Monday standup", Category.WORK),

     ],
     model = os.environ.get("BYLLM_DEFAULT_MODEL", "<unset>");

with entry {
    print(f"\n=== Model: {model} ({runs_per_prompt}x per prompt) ===");
}

glob correct = 0,
     total = 0,
     errors = 0;

with entry {
    for (title, expected) in cases {
        results: list = [];
        for _ in range(runs_per_prompt) {
            try {
                got = categorize(title);
                results.append(got);
                total += 1;
                if got == expected {
                    correct += 1;
                }
            } except Exception as e {
                results.append(f"<ERR:{type(e).__name__}>");
                total += 1;
                errors += 1;
            }
        }
        marks = " ".join(
            [
                ("✓" if r == expected else "·") if not isinstance(r, str) else "✗"
                for r in results
            ]
        );
        names = ", ".join([str(r).split(".")[-1] for r in results]);
        print(f"  [{marks}] {title!r:<42} expected={expected.name:<10} got=[{names}]");
    }
}

glob pct = (100.0 * correct / total) if total else 0.0;

with entry {
    print(f"\n  {correct}/{total} correct ({pct:.0f}%)  errors={errors}");
}
