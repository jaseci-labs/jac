import from pathlib { Path }
import from jaclang.compiler.api { link_client_graph }
import from jaclang.compiler.backends.es.link_facts { ClientLinkRequest }
import from jaclang.compiler.backends.common.artifacts {
    ClientArtifact,
    ClientManifest
}
import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.pipeline.progress {
    pipeline_progress,
    ProgressEvent,
    ProgressState
}
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.client.client_bundle { ClientBundleError }

test "client linking is scheduled and reuses provider artifacts" {
    program = JacProgram();
    main = Path('/tmp/client-link/main.jac');
    provider = Path('/tmp/client-link/provider.jac');
    loads: list[Path] = [];
    events: list[ProgressEvent] = [];
    def artifact(path: Path) -> ClientArtifact {
        loads.append(path);
        return ClientArtifact(
            '',
            ClientManifest(
                imports={'provider': str(provider)},
                runtime_imports={str(provider): ['answer']}
            )
                if path == main
                else ClientManifest(exports=['answer'])
        );
    }
    def variant(path: Path) -> Path {
        return path;
    }
    with pipeline_progress.listen(events.append) {
        result = link_client_graph(
            program, ClientLinkRequest([main], artifact, variant, set(), set())
        );
    }
    assert [unit.path for unit in result.modules] == [main, provider];
    assert loads == [main, provider];
    assert [
        event.state
        for event in events
        if event.operation == PassIdentity.ClientLinkPass.value
    ]
        == [ProgressState.STARTED, ProgressState.SUCCEEDED];
}

test "client linking reports unexported runtime imports as a failed product" {
    program = JacProgram();
    main = Path('/tmp/client-link/main.jac');
    provider = Path('/tmp/client-link/provider.jac');
    events: list[ProgressEvent] = [];
    def artifact(path: Path) -> ClientArtifact {
        return ClientArtifact(
            '',
            ClientManifest(runtime_imports={str(provider): ['private_value']})
                if path == main
                else ClientManifest()
        );
    }
    def variant(path: Path) -> Path {
        return path;
    }
    caught = False;
    with pipeline_progress.listen(events.append) {
        try {
            link_client_graph(
                program, ClientLinkRequest([main], artifact, variant, set(), set())
            );
        } except ClientBundleError as error {
            caught = True;
            assert 'private_value' in str(error);
        }
    }
    assert caught;
    assert events[-1].operation == PassIdentity.ClientLinkPass.value;
    assert events[-1].state == ProgressState.FAILED;
    assert not program.analysis.active;
}


test "self-host eviction preserves active queries across compilation contexts" {
    import from jaclang.compiler.bootstrap.selfhost { SelfHostCache }
    for child_context in [False, True] {
        owner = JacProgram();
        program = JacProgram() if child_context else owner;
        if child_context {
            program.context_root = owner;
        }
        owner.contexts['query'] = program;
        owner.scratch.na_unverified_live['pending'] = {};
        cache = SelfHostCache(_program=owner);
        main = Path('/tmp/client-link/eviction.jac');
        def artifact(path: Path) -> ClientArtifact {
            assert owner.has_active_compilation();
            assert program.analysis.active;
            cache.evict_unit(str(path), None, collect=False);
            owner._get_compiler()._release_compile_scratch(owner);
            owner.release_compile_closure(collect=False);
            assert program.analysis.active;
            assert 'pending' in owner.scratch.na_unverified_live;
            assert owner.contexts['query'] is program;
            return ClientArtifact('', ClientManifest());
        }
        def variant(path: Path) -> Path {
            return path;
        }
        result = link_client_graph(
            program, ClientLinkRequest([main], artifact, variant, set(), set())
        );
        assert [unit.path for unit in result.modules] == [main];
        assert not owner.has_active_compilation();
        cache.evict_unit(str(main), None, collect=False);
        assert not owner.contexts;
        assert not owner.scratch.na_unverified_live;
        assert not program.analysis.active;
    }
}
