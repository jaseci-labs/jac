"""Every service uses the application's schema namespace without sharing declarations."""
import from jaclang.project.persistence { parse_persistence }

test "project name is the default persistence namespace" {
    config = parse_persistence({}, 'example');
    assert config.module_facts('shared.models') == ('example', 'shared.models');
}

test "an explicit namespace is independent of deployment and service names" {
    config = parse_persistence({'namespace': 'com.example.accounts'}, 'deployment');
    assert config.module_facts('shared.models')
        == ('com.example.accounts', 'shared.models');
}

test "invalid namespaces and obsolete domain declarations are rejected" {
    for raw in [
        {'namespace': ''},
        {'namespace': 1},
        {'unexpected': True},
        {'domains': {}}
    ] {
        rejected = False;
        try {
            parse_persistence(raw, 'example');
        } except ValueError {
            rejected = True;
        }
        assert rejected , f'accepted {raw}';
    }
}
