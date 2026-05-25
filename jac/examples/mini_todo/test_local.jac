"""Smoke test for the bundled local LLM path.

Imports the same `categorize` symbol used by main.jac so we exercise
the exact MTIR path. add_todo() swallows exceptions, so we call
categorize directly here to surface the underlying error.
"""

import traceback;
import from main { Category, categorize, add_todo, get_todos }

glob inputs = [
         "Buy milk and bread",
         "Submit Q2 expense report",
         "Schedule annual physical exam",
         "Plan weekend hike with friends",

     ];

with entry {
    print("--- categorize() direct calls (local Gemma 4) ---");
    for t in inputs {
        try {
            cat = categorize(t);
            print(f"  {t!r:<40} -> {cat}");
        } except Exception as e {
            print(f"  {t!r:<40} -> ERROR {type(e).__name__}: {e}");
            traceback.print_exc();
        }
    }
    print("\n--- add_todo() flow (mirrors mini_todo) ---");
    for t in inputs {
        todo = add_todo(t);
        print(
            f"  {t!r:<40} -> category={todo.category!r:<20} priority={todo.priority}"
        );
    }
}
