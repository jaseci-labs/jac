"""Persistence domains are explicit, validated project facts."""
import from jaclang.project.persistence { parse_persistence }

test "domain identity is shared only by declared apps" {
    config = parse_persistence({
        'namespace': 'example.profiles',
        'domains': {'profiles': {
            'owner': 'writer', 'apps': ['writer', 'reader'], 'modules': ['shared.models']
        }}
    }, 'example', ['writer', 'reader', 'other']);
    writer = config.module_facts('shared.models', 'writer');
    reader = config.module_facts('shared.models', 'reader');
    assert writer[0] == reader[0] == 'example.profiles';
    assert writer[2:] == reader[2:];
    assert writer[1] != reader[1];
    assert config.module_facts('private.models', 'writer')[2] == 'app:writer';
    try {
        config.module_facts('shared.models', 'other');
        assert False, 'undeclared app gained access to a persistence domain';
    } except ValueError as error {
        assert 'without being a declared participant' in str(error);
    }
}

test "invalid domain declarations are rejected" {
    cases = [
        {'namespace': ''},
        {'unexpected': True},
        {'domains': {'d': {'owner': 'absent', 'apps': ['writer'], 'modules': ['models']}}},
        {'domains': {'d': {'owner': 'writer', 'apps': ['reader'], 'modules': ['models']}}},
        {'domains': {'d': {'owner': 'writer', 'apps': ['writer'], 'modules': ['shared.*']}}},
        {'domains': {'d': {'owner': 'writer', 'apps': ['writer'], 'modules': ['models', 'models']}}}
    ];
    for raw in cases {
        try {
            parse_persistence(raw, 'example', ['writer', 'reader']);
            assert False, f'accepted {raw}';
        } except ValueError {}
    }
}
