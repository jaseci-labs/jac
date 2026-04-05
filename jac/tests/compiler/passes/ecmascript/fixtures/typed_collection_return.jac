"""Fixture: SV returns typed collections to CL.

Tests dict[str, Obj], list[Obj], and nested collection types
crossing the codespace boundary.
"""

obj Metric {
    has name: str,
        value: float,
        unit: str = "";
}

obj Dashboard {
    has title: str,
        metrics: list[Metric],
        tags: dict = {};
}

def:pub get_metrics -> list[Metric] {
    return [
        Metric(name="cpu", value=45.2, unit="%"),
        Metric(name="mem", value=2.1, unit="GB")
    ];
}

def:pub get_dashboard -> Dashboard {
    return Dashboard(
        title="System",
        metrics=[Metric(name="cpu", value=45.2, unit="%")],
        tags={"env": "prod"}
    );
}

def:pub get_metrics_by_name -> dict {
    return {
        "cpu": Metric(name="cpu", value=45.2, unit="%"),
        "mem": Metric(name="mem", value=2.1, unit="GB")
    };
}

cl {
    sv import from .typed_collection_return { get_metrics, get_dashboard, get_metrics_by_name }

    def:pub app -> JsxElement {
        has dashboard: Any = None;

        async can with entry {
            dashboard = await get_dashboard();
        }

        return <div>
            <h1>{dashboard.title}</h1>
            {[<span key={m.name}>{m.name}: {m.value}{m.unit}</span>
              for m in dashboard.metrics]}
        </div>;
    }
}
