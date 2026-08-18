"""Concurrent subagents on jac-scale (sync walkers, auto thread-pool).

When served via `jac-scale serve`, sync walkers automatically run in a
thread pool (asyncio.to_thread).  Multiple concurrent HTTP requests get
their own walker instance and user_root — no shared state.

This file demonstrates the walker definitions you would deploy, plus a
local smoke-test that spawns them serially to verify correctness
(concurrency is handled by jac-scale at serve time).

Run locally (serial smoke-test):
    jac run scale_subagents.jac

Serve concurrently:
    jac-scale serve scale_subagents.jac --port 8000
"""

import from jaclang.byllm.llm { Model }
import time;

glob llm = Model(model_name="openrouter/google/gemma-2-9b-it:free");


# ---------------------------------------------------------------------------
# Sync walkers — blocking IO is fine; jac-scale wraps them in to_thread
# ---------------------------------------------------------------------------
walker research_walker {
    has topic: str,
        result: str = "";

    def answer(q: str) -> str by llm();
    can run with Root entry {
        self.result = self.answer(f"In one sentence, what is {self.topic}?");
        report {"topic": self.topic, "result": self.result};
    }
}

walker summarise_walker {
    has text: str,
        result: str = "";

    def summarise(t: str) -> str by llm();
    can run with Root entry {
        self.result = self.summarise(f"Summarise in ≤10 words: {self.text}");
        report {"text": self.text[:40] + "...", "result": self.result};
    }
}

walker translate_walker {
    has text: str,
        lang: str,
        result: str = "";

    def translate(t: str, target: str) -> str by llm();
    can run with Root entry {
        self.result = self.translate(
            f"Translate to {self.lang}: {self.text}", self.lang
        );
        report {"lang": self.lang, "result": self.result};
    }
}


# ---------------------------------------------------------------------------
# Local smoke-test (runs when executed directly, not under jac-scale)
# ---------------------------------------------------------------------------
with entry {
    print(
        "Local smoke-test (serial) — concurrency provided by jac-scale at serve time.\n"
    );
}

glob t0 = time.time(),
     r = research_walker(topic="the Jac programming language") spawn root,
     s = summarise_walker(
         text="Jac is a graph-native, agentic language built on Python that lets walkers traverse nodes."
     ) spawn root,
     tr = translate_walker(text="Hello, world!", lang="French") spawn root,
     elapsed = time.time() - t0;

with entry {
    print(f"[research_walker]   {r.result}");
    print(f"[summarise_walker]  {s.result}");
    print(f"[translate_walker]  {tr.result}");
    print(f"\nSerial wall-clock: {elapsed:.2f}s");
    print("\nTo serve concurrently: jac-scale serve scale_subagents.jac --port 8000");
}
