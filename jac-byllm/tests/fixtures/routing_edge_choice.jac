"""Routing fixture where the decision depends on EDGE attributes.

The two candidate Agent nodes are reachable from the Desk, and the correct
target is determined solely by the connecting edge's `priority` ("high" wins).
A model can only get this right if the routing prompt surfaces the edge of
each (edge, node) candidate pair -- which the new mechanism does and the old
node-only description does not.
"""

import re;
import from byllm.lib { MockLLM }
import from byllm.types { CompletionResult }
import from byllm.mtir { MTRuntime }


obj PriorityRouterMock(MockLLM) {
    """Reads the routing prompt and picks the candidate whose edge is high priority.

    Falls back to index 0 when no edge priority is visible in the prompt (the
    old mechanism's behaviour, since it never renders the edge).
    """
    override def dispatch_no_streaming(mt_run: MTRuntime) -> CompletionResult {
        text = "\n".join([str(getattr(m, "content", m)) for m in mt_run.messages]);
        self.seen_prompts.append(text);
        chosen: object = None;
        for line in text.splitlines() {
            norm = line.replace('"', "'");
            if "priority='high'" in norm {
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


glob llm: PriorityRouterMock = PriorityRouterMock(
         model_name="mockllm", config={"outputs": []}
     );


edge Route {
    has priority: str = "low";
}

node Desk {}

node Agent {
    has tag: str = "x";

    can handle with dispatcher entry {
        print("VISITED:" + self.tag);
    }
}

walker dispatcher {
    has request: str = "urgent escalation";

    can route with Desk entry {
        visit [-->] by llm(select=1, intent="Route along the highest priority edge");
    }
}

with entry {
    desk = root ++> Desk();
    desk +>:Route(priority="low"):+> Agent(tag="alpha");
    desk +>:Route(priority="high"):+> Agent(tag="beta");
    dispatcher() spawn desk;
}
