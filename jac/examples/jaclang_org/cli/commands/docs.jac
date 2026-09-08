import from core.docs.graph { DocsStatus, docs_status }
import from core.docs.sync { docs_sync_tick }
import from jaclang.server.bridge { BridgeError }
import from .common { EXIT_OK, explain_bridge_error }

def render_status(st: DocsStatus) -> str {
    if not st.ready {
        return "docs: the graph is empty, the web app has not ingested a corpus yet";
    }
    lines: list[str] = [
        "docs: ready · latest " + st.latest_label + " · built " + st.built_at
    ];
    for v in st.versions {
        lines.append(
            "  "
                + v.label
                + "  jac "
                + v.jac_version
                + "  "
                + str(v.pages)
                + " pages  fetched "
                + v.fetched_at
        );
    }
    return "\n".join(lines);
}

async def run_docs(action: str) -> int {
    try {
        if action == "sync" {
            await docs_sync_tick();
            print(
                "docs sync: the web app checked its graph against the bundled corpus"
            );
        }
        print(render_status(await docs_status()));
        return EXIT_OK;
    } except BridgeError as e {
        return explain_bridge_error(e);
    }
}
