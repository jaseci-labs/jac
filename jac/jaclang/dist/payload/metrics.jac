"""Producer-side build measurements, independent of buffered progress output."""

import json;
import os;
import sys;
import time;
import from collections.abc { Iterator }
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

def child_cpu_seconds -> float {
    try {
        import resource;
        usage = resource.getrusage(resource.RUSAGE_CHILDREN);
        return usage.ru_utime + usage.ru_stime;
    } except ImportError {
        return 0.0;
    }
}

def peak_rss_mb -> int {
    try {
        import resource;
        usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss;
        return int(usage // (1024 * 1024))
            if sys.platform == "darwin"
            else int(usage // 1024);
    } except ImportError {
        return 0;
    }
}

obj BuildMeasurements {
    has stages: list[StageMeasurement] = [];

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
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True);
        with open(path, "w", encoding="utf-8") as stream {
            json.dump(
                {
                    "schema": 1,
                    "timing": "inclusive; nested stages must not be summed",
                    "memory": "process peak RSS, excluding child processes",
                    "stages": [stage.record() for stage in self.stages]
                },
                stream,
                indent=2
            );
            stream.write("\n");
        }
    }
}
