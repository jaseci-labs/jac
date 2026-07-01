"""Regression: candidate nodes with identical field values are distinct targets.

Two parameterless `Item` nodes are reachable from the hub and the model selects
both. Value-based dedup (`picked not in chosen`, which delegates to dataclass
`__eq__`) would treat the two equal-valued instances as one and silently visit a
single node. Identity-based dedup keeps both, so the walker visits twice.
"""

import re;
import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.mtir { MTRuntime }


obj AllPicksMock(MockLLM) {
    """Selects every candidate handle offered in the routing prompt."""
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        text = "\n".join([str(getattr(m, "content", m)) for m in mt_run.messages]);
        self.seen_prompts.append(text);
        handles: list = [];
        in_candidates = False;
        for line in text.splitlines() {
            if line.startswith("Candidates") {
                in_candidates = True;
                continue;
            }
            if in_candidates {
                m = re.match(r"\s*([A-Za-z0-9_]+)\)", line);
                if m {
                    handles.append(m.group(1));
                }
            }
        }
        return CompletionResult(output=handles, tool_calls=[], usage={});
    }
}


glob llm: AllPicksMock = AllPicksMock(
         model_name="mockllm", config={"outputs": []}
     );


node Hub {}

node Item {
    can touch with collector entry {
        print("VISIT");
    }
}

walker collector {
    can go with Hub entry {
        visit [-->] by llm(select="all", intent="visit every item");
    }
}

with entry {
    hub = Hub();
    # Two parameterless Items -- equal by value, distinct as instances.
    hub ++> Item();
    hub ++> Item();
    collector() spawn hub;
}
