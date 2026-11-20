# Decision Models (System One)

Many `by llm()` functions don't need an LLM to write anything. `classify_priority` picks one of four labels; `is_spam` answers yes or no; a triage function fills in a handful of enum and bool fields. A chat model can do these, but it generates text you then parse, it is slow and priced per output token, and it cannot tell you how sure it is.

A **System One model** is built for exactly these calls. It reads the inputs and returns a probability for every possible answer, in one pass, with no generated text. TypeSafe's Jev was the first; open models such as OpenJev and Laya speak the same protocol. byLLM can send your closed-set functions to one of these without changing the functions at all.

This tutorial moves the classifier from [Structured Outputs](structured-outputs.md) onto a decision model, keeps a chat model for everything else, and uses the confidence it returns.

> **Prerequisites**
>
> - Completed: [Structured Outputs](structured-outputs.md)
> - A TypeSafe API key in `TYPESAFE_API_KEY` (or a local OpenJev server)
> - Project-wide, set `default_model = "systemone:typesafe/jev-latest"` under `[byllm.model]` in `jac.toml` and the builtin `llm` uses it
> - Time: ~15 minutes

---

## Switching the Model

Only the model name changes:

```jac
import from jaclang.byllm.lib { Model }

glob llm = Model(model_name="systemone:typesafe/jev-latest");

enum Priority {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

def classify_priority(ticket: str) -> Priority by llm();

with entry {
    print(classify_priority("Production database is down!"));
}
```

byLLM turns the call into one question: "which of `LOW`, `MEDIUM`, `HIGH`, `CRITICAL`?", with the ticket as the state, and returns the member the model rates most probable.

The format is `systemone:<provider>/<model>`. `typesafe` is TypeSafe's hosted API; `openjev` and `laya` point at a server on `localhost:8000`; `litellm` goes through a LiteLLM proxy.

---

## Describe Your Labels

A large chat model can guess what a label means from its name. A decision model is far smaller and relies on what your program says. `sem` on each member is sent as that label's description:

```jac
import from jaclang.byllm.lib { Model }

glob llm = Model(model_name="systemone:typesafe/jev-latest");

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, FITNESS, OTHER }

sem Category.WORK = "Job, employment, or professional obligations";
sem Category.OTHER = "Household chores and errands that fit no other category";

def categorize(title: str) -> Category by llm();
sem categorize = "Categorize a task based on its title";
```

Without the `sem` on `OTHER`, "Water the plants" tends to land in `PERSONAL`; with it, it lands in `OTHER`. The function's own `sem` becomes the question's instruction.

---

## Keep a Chat Model for Everything Else

A decision model can only answer questions with a fixed set of answers. A function returning `str`, a call with `tools=`, or a streaming call goes to the `fallback` instead, unchanged:

```jac
import from jaclang.byllm.lib { Model, Decision }

glob llm = Model(
    model_name="systemone:typesafe/jev-latest",
    config={"fallback": "gpt-4o-mini"}
);

enum Priority { LOW, HIGH }

def classify_priority(ticket: str) -> Priority by llm();   # decision model
def summarize(ticket: str) -> str by llm();                 # falls back to gpt-4o-mini
```

Without a `fallback`, calling `summarize` raises a `ConfigurationError` that says so.

---

## Use the Confidence

Declare the return type as `Decision[T]` to get the answer together with how sure the model is:

```jac
import from jaclang.byllm.lib { Model, Decision }

glob llm = Model(model_name="systemone:typesafe/jev-latest");

enum Priority { LOW, HIGH }

def classify_priority(ticket: str) -> Decision[Priority] by llm();

with entry {
    d = classify_priority("Can you change the font color?");
    if d.confidence < 0.6 {
        print(f"unsure ({d.confidence:.2f}), sending to a human");
    } else {
        print(d.value);
    }
}
```

`d.probabilities` holds the full distribution. Confidence is 1.0 when all probability sits on one answer and falls toward 0 as it spreads.

To let byLLM act on it for you, set `min_confidence`: answers below it are thrown away and the call is re-asked of the fallback. The cheap model handles the clear cases and the expensive one only sees the hard ones.

```jac
import from jaclang.byllm.lib { Model }

glob llm = Model(
    model_name="systemone:typesafe/jev-latest",
    config={"fallback": "claude-sonnet-4-6", "min_confidence": 0.7}
);
```

---

## Beyond a Single Label

The same model answers more than one question per call:

```jac
import from jaclang.byllm.lib { Model }

glob llm = Model(model_name="systemone:typesafe/jev-latest");

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, FITNESS, OTHER }

obj Triage {
    has category: Category,
        urgent: bool;
}

def triage(task: str) -> Triage by llm();
def tags(task: str) -> list[Category] by llm();
```

`triage` asks one question per field in a single request and builds the `Triage`. `tags` asks yes or no for every category and returns those that apply, most likely first. An object with any `str` or number field goes to the fallback, since that field has no fixed set of answers.

`visit [-->] by llm()` works too: the candidates are the answers, and `select=` controls how many are visited.

---

## Testing Without a Key

`MockSystemOne` scripts the decision model the way `MockLLM` scripts a chat model:

```jac
import from jaclang.byllm.lib { Decision, MockSystemOne }

glob so1 = MockSystemOne(
    answers=[{"value": {"type": "choice", "choice": "HIGH", "confidence": 0.9}}]
);

enum Priority { LOW, HIGH }

def classify_priority(ticket: str) -> Priority by so1();

test "an outage is high priority" {
    assert classify_priority("Production database is down!") == Priority.HIGH;
}
```

---

## Key Takeaways

| Want | Do |
|------|----|
| Send closed-set functions to a decision model | `model_name="systemone:<provider>/<model>"` |
| Make labels understood | `sem` on each enum member |
| Handle `str`, tools, streaming | `config={"fallback": "<chat model>"}` |
| Read how sure it was | `-> Decision[T]` |
| Escalate unsure answers automatically | `config={"min_confidence": 0.7}` |

---

## Next Steps

- [Agentic AI](agentic.md) - Add tools for the LLM to use
- [byLLM Reference: System One Models](../../reference/plugins/byllm.md#system-one-models) - Providers, limits, and how confidence is computed
