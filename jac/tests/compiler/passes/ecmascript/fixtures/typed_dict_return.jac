"""Fixture: SV returns dict[str, Obj] to CL.

Tests that when a def:pub function returns a dict with typed values,
the compiler generates hydration wrappers for the dict values.
"""

obj Metric {
    has name: str,
        value: float,
        unit: str = "";
}

def:pub get_metrics_map -> dict[str, Metric] {
    return {
        "cpu": Metric(name="cpu", value=45.2, unit="%"),
        "mem": Metric(name="mem", value=2.1, unit="GB")
    };
}

def:pub get_single_metric(name: str) -> Metric {
    return Metric(name=name, value=0.0);
}

cl {
    sv import from .typed_dict_return { get_metrics_map, get_single_metric }

    def:pub app -> JsxElement {
        has metrics: Any = None;

        async can with entry {
            metrics = await get_metrics_map();
        }

        return <div>
            <span>{metrics}</span>
        </div>;
    }
}
