# Multistage Visit Routing

`visit ... by llm(...)` lets a byllm model choose which node(s) a walker visits
next. This example documents the **multistage** routing mode and the change that
makes it render walker/node context **untruncated**, and ships a self-contained
demo (`demo.jac`) that shows the difference — no API key required.

## how current single-stage routing works

When you write `visit [-->] by llm(...)`, byllm builds a prompt describing the
walker, the current node, and each candidate node, then asks the model to pick.
Every field value in that description is rendered through an internal
`_safe_repr` helper that **caps each value at 120 characters** — keeping the
first ~57 and last ~57 characters and replacing the middle with `...`.

That cap keeps routing prompts small, but it is a blind, middle-dropping
truncation. Anything in the *middle* of a long field — a walker's accumulated
conversation history, a case note, a long refined goal — is deleted before the
model ever sees it. The routing decision is made on partial context.

## Multistage routing

Enable it by passing `multistage=True`:

```jac
visit [-->] by llm(
    select   = 1,
    intent   = "Move to Research once the initiative is understood; otherwise ask a follow-up.",
    multistage = True,
);
```

Instead of one constrained call that must commit to a choice immediately,
multistage splits the decision into a short pipeline:

1. **Condense** — the caller's `intent` / `incl_info` are compressed once into a
   brief and cached, so a multi-hop traversal pays that cost a single time
   rather than re-sending the full context on every hop. (Skipped for short
   intents, where condensing would cost more than it saves.)
2. **Reason** — the routing decision is made in a **free-text** reasoning call
   that ends in a `CHOICE: <handle>` line. This call has room for full context
   and actual reasoning tokens, which small models handle far more reliably than
   forced constrained decoding.
3. **Extract** — the structured choice is read off the `CHOICE:` line for free;
   only a malformed line triggers a short fallback extraction call.

### What changed: untruncated context in multistage

Because the multistage **reason** call is free-text and built to hold full
context, it renders walker/node field values **without the 120-char cap**. The
single-stage path is unchanged and still truncates.

Concretely, the render helpers now take a `limit` argument
(`jaclang/byllm/visit_routing.jac`): single-stage calls them with the default
`limit=120`; multistage calls them with `limit=None` (no truncation).

Result: information buried in the middle of a long field reaches the multistage
router but is invisible to the single-stage router.

## Parameters

Added these 2 keyword arguments to `by llm(...)` on a `visit`:

| Parameter    | Meaning |
| `incl_info`  | A `dict` of extra key/value context. Rendered verbatim (never truncated) in both modes. |
| `multistage` | `True` enables the condense → reason → extract pipeline and untruncated field rendering. |

Include `[here]` in the candidate set (`visit ([-->] + [here]) by llm(...)`) when
you want the router to be able to *stay* on the current node and loop.

> **Note:** the keyword is `multistage`. A misspelling such as `mutlistage` is silently forwarded to the model as an API parameter rather than enabling the feature, so double-check the spelling.

## Running the demo

```bash
cd jaclang/byllm/examples/visit_routing_multistage
jac run demo.jac
```

The demo drives one identical graph and walker through both modes. The walker
carries a long `case_notes` field with a fraud flag,
`INTERNAL_FRAUD_FLAG_ESCALATE`, buried in the middle. The routing rule is the
same for both modes — "escalate if you see the fraud flag" — so the only
variable is whether the router can see it.

Expected output:

```
=== MULTISTAGE: field rendered untruncated, router sees the flag ===
  [router LLM | multistage ] fraud flag visible in prompt: True
  --> LANDED: EscalationDesk (fraud / tier-2 queue)

=== SINGLE-STAGE: field truncated at 120 chars, flag is hidden ===
  [router LLM | single-stage] fraud flag visible in prompt: False
  --> LANDED: BillingDesk (default billing queue)
```

Multistage sees the flag and escalates; single-stage never sees it and falls
through to the default queue.

## When to use multistage

- **Long walker/node state that matters for routing** — accumulated
  conversation history, case notes, refined goals. Middle-of-field detail
  survives only under multistage.
- **Small / local models** — the free-text reason stage is more reliable than
  one-shot constrained decoding.
- **Deep traversals with a stable `intent`** — condensation is computed once and
  cached across hops.

Single-stage remains the lighter-weight default when routing context is short
and fits comfortably under the 120-char per-field cap.

## Files edited

```
visit_routing_multistage/
├── demo.jac    # Runnable MockLLM demo comparing both modes
└── README.md   # This file


```
