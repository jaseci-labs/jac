import json;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.dist.payload.metrics { BuildMeasurements }
import from jaclang.dist.payload.assemble { MkPayloadOpts }

test "build measurements survive failed stages and describe nested timing" {
    measurements = BuildMeasurements();
    with measurements.stage("payload") {
        with measurements.stage("complete") {}
        try {
            with measurements.stage("failed") {
                raise ValueError("producer failed");
            }
        } except ValueError {}
    }
    with TemporaryDirectory() as directory {
        output = Path(directory) / "metrics/payload.json";
        measurements.write(str(output));
        data = json.loads(output.read_text());
        assert data["schema"] == 1;
        assert "must not be summed" in data["timing"];
        stages = data["stages"];
        assert [stage["name"] for stage in stages] == ["complete", "failed", "payload"];
        assert stages[0]["succeeded"];
        assert not stages[1]["succeeded"];
        assert stages[2]["succeeded"];
        assert stages[2]["wall_seconds"] >= stages[0]["wall_seconds"];
        for stage in stages {
            for name in (
                "wall_seconds",
                "cpu_seconds",
                "child_cpu_seconds",
                "peak_rss_mb"
            ) {
                assert stage[name] >= 0;
            }
        }
    }
}

test "independent builds own their measurements" {
    first = MkPayloadOpts();
    second = MkPayloadOpts();
    with first.measurements.stage("first") {}
    assert len(first.measurements.stages) == 1;
    assert not second.measurements.stages;
}

test "stage checkpoints retain completed work during an unfinished build" {
    with TemporaryDirectory() as directory {
        output = Path(directory) / "metrics/payload.json";
        measurements = BuildMeasurements(output_path=str(output));
        with measurements.stage("payload") {
            with measurements.stage("kernel") {
                data = json.loads(output.read_text());
                assert data["active_stages"] == ["payload", "kernel"];
                assert not data["stages"];
                measurements.cache_outcome("kernel", "hit");
                assert json.loads(output.read_text())["cache_outcomes"]["kernel"]
                    == {"hit": 1};
            }
            data = json.loads(output.read_text());
            assert data["active_stages"] == ["payload"];
            assert data["stages"][0]["name"] == "kernel";
            try {
                with measurements.stage("catalog") {
                    raise ValueError("producer failed");
                }
            } except ValueError {}
            data = json.loads(output.read_text());
            assert data["active_stages"] == ["payload"];
            assert not data["stages"][-1]["succeeded"];
        }
        assert not json.loads(output.read_text())["active_stages"];
    }
}
