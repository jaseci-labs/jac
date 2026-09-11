"""Program under test for `visit ... by llm()` routing.

Shape only: no model, no entry block, no prints. The test assigns `llm`, builds
its graph and spawns a walker.

`router` follows `[-->]`, `picker` takes an arbitrary node list that need not be
adjacent, `collector` selects every candidate, `stream_router` streams the
decision, `leaky` passes routing-control params alongside a real one.
"""

glob llm: any = None;

edge Route {
    has priority: str = "low";
}

node Hub {}

node Agent {
    has tag: str = "x";

    can log with router entry {
        visitor.visited.append(self.tag);
    }

    can log_picked with picker entry {
        visitor.visited.append(self.tag);
    }

    can log_collected with collector entry {
        visitor.visited.append(self.tag);
    }

    can log_streamed with stream_router entry {
        visitor.visited.append(self.tag);
    }
}

walker router {
    has visited: list = [];

    can route with Hub entry {
        visit [-->] by llm(select=1, intent="Route to the right agent");
    }
}

walker picker {
    has options: list = [],
        visited: list = [];

    can pick with Hub entry {
        visit self.options by llm(select=1, intent="Pick one target");
    }
}

walker collector {
    has visited: list = [];

    can go with Hub entry {
        visit [-->] by llm(select="all", intent="Visit every item");
    }
}

walker leaky {
    has visited: list = [];

    can route with Hub entry {
        visit [-->] by llm(
            select=1, intent="go", incl_info={"k": "v"}, temperature=0.5
        );
    }
}


"""Tokens the routing decision streamed, as a live token feed would consume them."""
glob streamed: list = [];

def route_sink(ev: any) {
    if ev.event_type == "chunk" {
        streamed.append(str(ev.data.get("content", "")));
    }
}


walker stream_router {
    has visited: list = [];

    can route with Hub entry {
        visit [-->] by llm(stream=True, stream_handler=route_sink);
    }
}
