import argparse;
import json;
import math;
import os;
import platform;
import statistics;
import sys;
import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.lsp_client { LspClient, RpcEvent }
import from scripts.ci_perf { Budget, Measurement, record, write_json }

obj Samples {
    has seconds: list[float] = [];

    def add(started: float, event: RpcEvent) {
        if 'error' in event.body {
            raise RuntimeError(json.dumps(event.body['error']));
        }
        self.seconds.append(event.timestamp - started);
    }

    def summary -> dict[str, object] {
        ordered = sorted(self.seconds);
        return {
            'samples_seconds': self.seconds,
            'median_seconds': statistics.median(ordered),
            'p95_seconds': self.p95(),
            'max_seconds': max(ordered)
        };
    }

    def p95 -> float {
        ordered = sorted(self.seconds);
        return ordered[max(0, math.ceil(len(ordered) * 0.95) - 1)];
    }
}

def semantic_result(method: str, event: RpcEvent) -> RpcEvent {
    value = event.body.get('result');
    if not value
        or (method == 'completion' and not value.get('items'))
        or (method == 'semanticTokens/full' and not value.get('data')) {
        raise RuntimeError(f'{method} returned no semantic result: {event.body}');
    }
    return event;
}

def fixture(
    directory: Path, functions: int, annex: bool = False
) -> tuple[Path, str, dict] {
    (directory / 'jac.toml').write_text('[project]\nname="lsp-benchmark"\n');
    source = (
        'obj Counter {\n    has value: int = 0;\n'
        '    def add(delta: int) -> int {\n'
        '        return self.value + delta;\n    }\n}\n'
    );
    implementation = '';
    for index in range(functions) {
        body = f'calc_{index}(x: int) -> int {{\n    y = x + {index};\n    return y * 2;\n}}\n';
        if annex {
            source += f'def calc_{index}(x: int) -> int;\n';
            implementation += 'impl ' + body;
        } else {
            source += 'def ' + body;
        }
    }
    source += 'with entry {\n    counter = Counter();\n    print(counter.add(calc_0(1)));\n}\n';
    path = directory / 'main.jac';
    path.write_text(source);
    params = {
        'textDocument': {'uri': path.as_uri()},
        'position': {'line': len(source.splitlines()) - 2, 'character': 11}
    };
    if annex {
        path = directory / 'main.impl.jac';
        source = implementation;
        path.write_text(source);
    }
    return (path, source, params);
}

def single_file(
    client: LspClient, directory: Path, functions: int, rounds: int, annex: bool = False
) -> dict[str, Samples] {
    (path, source, params) = fixture(directory, functions, annex);
    times: dict[str, Samples] = {};
    opened = Samples();
    start = time.monotonic();
    client.open(str(path), source);
    opened.add(
        start,
        client.diagnostics(
            str(path), 1, timeout=300.0, since=start, allow_unversioned=True
        )
    );
    times['open'] = opened;
    for method in [
        'hover',
        'definition',
        'completion',
        'documentSymbol',
        'semanticTokens/full'
    ] {
        samples = Samples();
        # The first lazy query is reported separately from steady state.
        first = Samples();
        start = time.monotonic();
        first.add(
            start,
            semantic_result(
                method, client.request('textDocument/' + method, params, timeout=120.0)
            )
        );
        times[method.replace('/', '-') + '-first'] = first;
        for _ in range(rounds) {
            start = time.monotonic();
            samples.add(
                start,
                semantic_result(
                    method,
                    client.request('textDocument/' + method, params, timeout=120.0)
                )
            );
        }
        times[method.replace('/', '-')] = samples;
    }
    version = 1;
    diagnostics = Samples();
    completions = Samples();
    hovers = Samples();
    bursts = Samples();
    for _ in range(rounds) {
        version += 1;
        start = time.monotonic();
        client.change(
            str(path), source.replace('y = x + 0;', f'y = x + {version};', 1), version
        );
        diagnostics.add(
            start,
            client.diagnostics(
                str(path), version, timeout=120.0, since=start, allow_unversioned=True
            )
        );
        version += 1;
        start = time.monotonic();
        client.change(
            str(path), source.replace('y = x + 0;', f'y = x + {version};', 1), version
        );
        completion = client.send_request('textDocument/completion', params);
        hover = client.send_request('textDocument/hover', params);
        completions.add(
            start,
            semantic_result('completion', client.response(completion, timeout=120.0))
        );
        hovers.add(
            start, semantic_result('hover', client.response(hover, timeout=120.0))
        );
        client.diagnostics(
            str(path), version, timeout=120.0, since=start, allow_unversioned=True
        );
        start = time.monotonic();
        for _ in range(10) {
            version += 1;
            client.change(
                str(path),
                source.replace('y = x + 0;', f'y = x + {version};', 1),
                version
            );
        }
        bursts.add(
            start,
            client.diagnostics(
                str(path), version, timeout=120.0, since=start, allow_unversioned=True
            )
        );
        client.discard_before(time.monotonic());
    }
    times.update(
        {
            'edit-diagnostics': diagnostics,
            'edit-completion': completions,
            'queued-hover': hovers,
            'burst-diagnostics': bursts
        }
    );
    cancelled = Samples();
    version += 1;
    client.change(
        str(path),
        source
            + '\n'.join(
                f'def cancel_{index} -> int {{ return {index}; }}'
                for index in range(500)
            ),
        version
    );
    request = client.send_request('textDocument/completion', params);
    started = time.monotonic();
    client.notify('$/cancelRequest', {'id': request});
    response = client.response(request, timeout=120.0);
    assert 'result' in response.body
        or response.body.get('error', {}).get('code') == -32800;
    cancelled.seconds.append(response.timestamp - started);
    times['cancel'] = cancelled;
    return times;
}

def workspace(
    client: LspClient, directory: Path, documents: int, rounds: int
) -> dict[str, Samples] {
    library = directory / 'library.jac';
    good = 'def:pub value -> int { return 1; }\n';
    bad = 'def:pub value -> str { return "changed"; }\n';
    library.write_text(good);
    paths: list[Path] = [];
    for index in range(documents) {
        path = directory / f'consumer_{index}.jac';
        source = 'import from .library { value }\ndef use -> int { return value(); }\n';
        path.write_text(source);
        paths.append(path);
        client.open(str(path), source);
    }
    for path in paths {
        assert not client.diagnostics(str(path), 1, timeout=300.0).body['params'][
            'diagnostics'
        ];
    }
    fanout = Samples();
    for turn in range(rounds * 2) {
        broken = turn % 2 == 0;
        library.write_text(bad if broken else good);
        started = time.monotonic();
        client.notify(
            'workspace/didChangeWatchedFiles',
            {'changes': [{'uri': library.as_uri(), 'type': 2}]}
        );
        latest: RpcEvent | None = None;
        for path in paths {
            event = client.until(
                lambda (body: dict) -> bool { return body.get('method')
                    == 'textDocument/publishDiagnostics'
                    and body.get('params', {}).get('uri') == path.as_uri(); },
                since=started,
                timeout=300.0
            );
            errors = [
                item
                for item in event.body['params']['diagnostics']
                if item.get('severity') == 1
            ];
            assert bool(errors) == broken , f'dependency diagnostics are stale for {path}';
            if latest is None or event.timestamp > latest.timestamp {
                latest = event;
            }
        }
        assert latest is not None;
        fanout.add(started, latest);
        client.discard_before(time.monotonic());
    }
    return {'dependency-fanout': fanout};
}

def soak(
    client: LspClient, directory: Path, iterations: int
) -> tuple[Samples, list[float]] {
    memory: list[float] = [];
    cycle = Samples();
    for index in range(iterations) {
        path = directory / f'cycle_{index}.jac';
        dependency = directory / f'library_{index}.jac';
        dependency.write_text('def:pub value -> int { return 1; }\n');
        source = f'import from .library_{index} {{ value }}\ndef use -> int {{ return value(); }}\n';
        path.write_text(source);
        started = time.monotonic();
        client.open(str(path), source);
        client.diagnostics(str(path), 1, timeout=120.0);
        client.change(str(path), source + '# changed\n', 2);
        client.diagnostics(str(path), 2, timeout=120.0);
        closing = time.monotonic();
        client.notify(
            'textDocument/didClose', {'textDocument': {'uri': path.as_uri()}}
        );
        released = client.until(
            lambda (body: dict) -> bool { return body.get('method')
                == 'textDocument/publishDiagnostics'
                and body.get('params', {}).get('uri') == path.as_uri()
                and body.get('params', {}).get('version') is None; },
            since=closing,
            timeout=120.0
        );
        cycle.add(started, released);
        rss = client.rss_mib();
        if rss is not None {
            memory.append(rss);
        }
        client.discard_before(time.monotonic());
        if index % 10 == 0 {
            print(f'soak: {index + 1}/{iterations}, RSS {rss} MiB', flush=True);
        }
    }
    return (cycle, memory);
}

def main -> int {
    parser = argparse.ArgumentParser(
        description='Measure real stdio language-server latency and retention.'
    );
    parser.add_argument(
        '--scenario',
        choices=['small', 'medium', 'large', 'annex', 'workspace', 'soak'],
        `default='medium'
    );
    parser.add_argument('--rounds', type=int, `default=5);
    parser.add_argument('--documents', type=int, `default=20);
    parser.add_argument('--iterations', type=int, `default=100);
    parser.add_argument('--output', type=Path, `default=Path('lsp-performance'));
    parser.add_argument(
        '--server', help='Jac executable to benchmark; defaults to the running Jac.'
    );
    parser.add_argument(
        '--sealed-server',
        action='store_true',
        help='Disable the checkout override in the child server; use this when comparing built binaries.'
    );
    parser.add_argument(
        '--budgets',
        type=Path,
        help='Optional scenario-to-operation Budget JSON; compare p95 wall time and process peak RSS.'
    );
    args = parser.parse_args();
    if min(args.rounds, args.documents, args.iterations) < 1 {
        parser.error('rounds, documents and iterations must be positive');
    }
    budgets: dict[str, Budget] = {};
    if args.budgets is not None {
        budgets = {
            name: Budget(**value)
            for (name, value) in json.loads(args.budgets.read_text())[args.scenario].items()
        };
    }
    failures: list[str] = [];
    with TemporaryDirectory(prefix='jac-lsp-bench-') as directory {
        client = LspClient(
            directory,
            command=[args.server or sys.executable, 'lsp'],
            environment={'JAC_NO_DEV_SOURCE': '1'} if args.sealed_server else None
        );
        try {
            results: dict[str, object] = {
                'scenario': args.scenario,
                'startup_seconds': client.startup_seconds,
                'server': args.server or sys.executable,
                'platform': platform.platform(),
                'compiler_kernel': os.environ.get('JAC_COMPILER_LIB', 'automatic'),
                'dev_source_disabled': args.sealed_server
                    or bool(os.environ.get('JAC_NO_DEV_SOURCE')),
                'rounds': args.rounds
            };
            if args.scenario == 'soak' {
                (cycle, memory) = soak(client, Path(directory), args.iterations);
                samples = {'soak-cycle': cycle};
                results['rss_samples_mib'] = memory;
            } else {
                samples = workspace(
                    client, Path(directory), args.documents, args.rounds
                )
                    if args.scenario == 'workspace'
                    else single_file(
                        client,
                        Path(directory),
                        {'small': 10, 'medium': 250, 'large': 1250, 'annex': 250}[
                            args.scenario
                        ],
                        args.rounds,
                        annex=args.scenario == 'annex'
                    );
            }
            samples['startup'] = Samples([client.startup_seconds]);
            results['operations'] = {
                name: values.summary() for (name, values) in samples.items()
            };
            for (name, budget) in budgets.items() {
                if name not in samples {
                    failures.append(f'missing measurement: {name}');
                    continue;
                }
                failures.extend(
                    record(
                        args.output,
                        args.scenario + '-' + name,
                        Measurement(
                            samples[name].p95(), max_rss_mib=client.rss_mib(peak=True)
                        ),
                        budget
                    )
                );
            }
            results['final_rss_mib'] = client.rss_mib();
            results['peak_rss_mib'] = client.rss_mib(peak=True);
            results['failures'] = failures;
            write_json(args.output / (args.scenario + '.json'), results);
            print(json.dumps(results, indent=2), flush=True);
        } finally {
            client.close();
        }
    }
    return int(bool(failures));
}

with entry:__main__ {
    sys.`exit(main());
}
