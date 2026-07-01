"""Routing over an ARBITRARY, non-adjacent node list (not a `[-->]` traversal).

`visit` accepts any node list, not just edge-ref successors. Here the candidates
are standalone nodes with no edge to `here`, so the prompt must render them
node-only -- no fabricated `here --(...)-->` arrow and no `(direct)` placeholder.
The mock flags any such fabricated-edge framing; routing must still select a node.
"""

import re;
import from jaclang.byllm.lib { MockLLM }
import from jaclang.byllm.types { CompletionResult }
import from jaclang.byllm.mtir { MTRuntime }


obj NodeListMock(MockLLM) {
    """Flags fabricated-edge framing, then picks the first candidate handle."""
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        text = "\n".join([str(getattr(m, "content", m)) for m in mt_run.messages]);
        self.seen_prompts.append(text);
        if ("(direct)" in text) or ("here --" in text) or ("here <-" in text) {
            print("FABRICATED_EDGE");
        }
        chosen: object = None;
        in_candidates = False;
        for line in text.splitlines() {
            if line.startswith("Candidates") {
                in_candidates = True;
                continue;
            }
            if in_candidates {
                m = re.match(r"\s*([A-Za-z0-9_]+)\)", line);
                if m {
                    chosen = m.group(1);
                    break;
                }
            }
        }
        out = [chosen] if chosen is not None else [0];
        return CompletionResult(output=out, tool_calls=[], usage={});
    }
}


glob llm: NodeListMock = NodeListMock(
         model_name="mockllm", config={"outputs": []}
     );


node Here {}

node Target {
    has tag: str = "x";

    can land with picker entry {
        print("VISITED:" + self.tag);
    }
}

walker picker {
    has options: list = [];

    can pick with Here entry {
        visit self.options by llm(select=1, intent="Pick one target");
    }
}

with entry {
    start = root ++> Here();
    # Standalone targets -- intentionally NOT connected to `start`.
    a = Target(tag="alpha");
    b = Target(tag="beta");
    picker(options=[a, b]) spawn start;
}
