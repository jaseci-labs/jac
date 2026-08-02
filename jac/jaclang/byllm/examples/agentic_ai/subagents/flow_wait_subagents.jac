"""Concurrent subagents using flow/wait (Jac-native parallelism).

Three specialised walkers run concurrently via `flow` and `wait`.
Each walker carries its own conversation, so byLLM state is fully
isolated. Wall-clock time should be close to the slowest single call,
not the sum of all calls.

Run:
    jac run flow_wait_subagents.jac
"""

import from jaclang.byllm.llm { Model }
import time;

glob llm = Model(model_name="openrouter/google/gemma-2-9b-it:free");

# ---------------------------------------------------------------------------
# Specialised subagent walkers
# ---------------------------------------------------------------------------
walker researcher {
    has topic: str,
        result: str = "";

    def answer(q: str) -> str by llm();
    can run with Root entry {
        self.result = self.answer(f"In one sentence, what is {self.topic}?");
    }
}

walker summariser {
    has text: str,
        result: str = "";

    def summarise(t: str) -> str by llm();
    can run with Root entry {
        self.result = self.summarise(f"Summarise in ≤10 words: {self.text}");
    }
}

walker translator {
    has text: str,
        lang: str,
        result: str = "";

    def translate(t: str, target: str) -> str by llm();
    can run with Root entry {
        self.result = self.translate(
            f"Translate to {self.lang}: {self.text}", self.lang
        );
    }
}

# ---------------------------------------------------------------------------
# Orchestrator — spawns all three concurrently, waits for results
# ---------------------------------------------------------------------------
glob t_start = time.time(),
     # flow spawns each walker on root without blocking
     r_task = flow researcher(topic="the Jac programming language") spawn root ,
     s_task = flow summariser(
         text="Jac is a graph-native, agentic language built on Python that lets walkers traverse nodes."
     ) spawn root ,
     tr_task = flow translator(text="Hello, world!", lang="French") spawn root ,
     # wait collects results — blocks until the walker finishes
     r_done = wait r_task ,
     s_done = wait s_task ,
     tr_done = wait tr_task ,
     elapsed = time.time() - t_start;

with entry {
    print(f"\n[researcher]  {r_done.result}");
    print(f"[summariser]  {s_done.result}");
    print(f"[translator]  {tr_done.result}");
    print(f"\nWall-clock: {elapsed:.2f}s  (concurrent — close to max, not sum)");
}
