"""Producer-side build measurements, independent of buffered progress output."""

import json;
import time;
import from jaclang.jac0core.resource_usage { child_cpu_seconds, peak_rss_mb }
import from contextlib { contextmanager }

obj StageMeasurement {
    has name: str,
        wall_seconds: float,
        cpu_seconds: float,
        child_cpu_seconds: float,
        peak_rss_mb: int,
        succeeded: bool;

    def record -> dict[str, str | float | int | bool] {
        return {
            "name": self.name,
            "wall_seconds": self.wall_seconds,
            "cpu_seconds": self.cpu_seconds,
            "child_cpu_seconds": self.child_cpu_seconds,
            "peak_rss_mb": self.peak_rss_mb,
            "succeeded": self.succeeded
        };
    }
}

obj BuildMeasurements {
    has stages: list[StageMeasurement] = [],
        cache_outcomes: dict[str, dict[str, int]] = {},
        compilation: dict[str, any] = {};

    def cache_outcome(producer: str, outcome: str) {
        outcomes = self.cache_outcomes.setdefault(producer, {});
        outcomes[outcome] = outcomes.get(outcome, 0) + 1;
    }

    @contextmanager
    def stage(name: str) -> Iterator[None] {
        wall = time.perf_counter();
        cpu = time.process_time();
        children = child_cpu_seconds();
        succeeded = False;
        try {
            yield ;
            succeeded = True;
        } finally {
            self.stages.append(
                StageMeasurement(
                    name,
                    time.perf_counter() - wall,
                    time.process_time() - cpu,
                    child_cpu_seconds() - children,
                    peak_rss_mb(),
                    succeeded
                )
            );
        }
    }

    def write(path: str) {
        import from jaclang.jac0core.cache_paths { atomic_write }
        data = json.dumps(
            {
                "schema": 1,
                "timing": "inclusive; nested stages must not be summed",
                "memory": "process peak RSS, excluding child processes",
                "stages": [stage.record() for stage in self.stages],
                "cache_outcomes": self.cache_outcomes,
                "compilation": self.compilation
            },
            indent=2
        );
        atomic_write(path, (data + "\n").encode());
    }
}
