"""Schema repair v1 unit tests: `__jac_schema__` rules + repair engine.

Covers the declarative drift-rule surface (schema_was / schema_alias /
schema_drop / schema_upgrade collected from a `__jac_schema__` static
method at registration time) and the repair engine that applies those
rules to raw stored dicts before field deserialization. Complements
test_layer3_coercion_alias.jac (class aliases + coercion) and
test_persistence_migration.jac (fingerprints).
"""

import os;
import from jaclang.jac0core.archetype { NodeAnchor, Root }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.schema_rules {
    SchemaRules,
    merged_rules_for,
    schema_alias as direct_schema_alias,
    validate_rules
}


"""Upgrade callback: legacy comma-string tags become list[str]."""
def _split_tags(doc: dict) -> dict {
    doc['tags'] = [
        t.strip()
        for t in doc['tags'].split(',')
        if t.strip()
    ];
    return doc;
}


obj _DriftUser(Root) {
    has name: str = "",
        tags: list[str] = [],
        email: str = "";

    static def __jac_schema__ -> None;
}

impl _DriftUser.__jac_schema__ -> None {
    schema_was("oldapp.models._DriftOldUser");
    schema_alias("name", stored="username");
    schema_drop("legacy_bio");
    schema_upgrade(
        _split_tags, when=(lambda (doc: dict) { isinstance(doc.get('tags'), str); })
    );
}


obj _DriftAdmin(_DriftUser) {
    has level: int = 0;
}


obj _NoRules(Root) {
    has name: str = "";
}


obj _FactoryDefaults(Root) {
    has name: str = "",
        items: list[str] = [],
        meta: dict[str, str] = {};
}


"""Build a raw stored dict shaped like a pre-rename _DriftUser document."""
def _old_user_raw -> dict {
    return {
        '__type__': '_DriftUser',
        '__module__': getattr(_DriftUser, '__module__'),
        'username': 'ada',
        'tags': 'math, computing',
        'legacy_bio': 'wrote the first program',
        'email': 'ada@example.com'
    };
}


# --- Rule collection at registration ---------------------------------------
test "rules are collected from __jac_schema__ at class registration" {
    rules = merged_rules_for(_DriftUser);
    assert rules is not None , "no rules collected for _DriftUser";
    assert len(rules.aliases) == 1;
    assert rules.aliases[0].new_name == 'name';
    assert rules.aliases[0].stored_name == 'username';
    assert len(rules.drops) == 1 and rules.drops[0].field_name == 'legacy_bio';
    assert len(rules.upgrades) == 1;
}


test "schema_was registers a class alias to the defining class" {
    mod = getattr(_DriftUser, '__module__');
    assert Serializer._aliases.get("oldapp.models._DriftOldUser") == f"{mod}._DriftUser" , (
        f"was-alias not registered: {Serializer._aliases}"
    );
}


test "field rules are inherited by subclasses; was-rules are definer-only" {
    rules = merged_rules_for(_DriftAdmin);
    assert rules is not None , "subclass did not inherit field rules";
    assert any(a.new_name == 'name' for a in rules.aliases);
    # The was-alias must still point at the definer, not the subclass.
    mod = getattr(_DriftUser, '__module__');
    assert Serializer._aliases.get("oldapp.models._DriftOldUser") == f"{mod}._DriftUser";
}


test "classes without __jac_schema__ have no rules" {
    assert merged_rules_for(_NoRules) is None;
}


# --- Repair engine: rename / upgrade / drop ---------------------------------
test "repair renames aliased field and runs upgrade callback on load" {
    raw = _old_user_raw();
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert getattr(arch, 'name') == 'ada' , "username was not renamed to name";
    assert getattr(arch, 'tags') == ['math', 'computing'] , (
        f"upgrade callback did not run: {arch?.tags}"
    );
    assert getattr(arch, 'email') == 'ada@example.com';
    repairs = arch?.__jac_schema_repairs__;
    assert repairs , "applied repair steps were not recorded on the instance";
}


test "repair is idempotent: already-repaired data is untouched" {
    current = {
        '__type__': '_DriftUser',
        '__module__': getattr(_DriftUser, '__module__'),
        'name': 'ada',
        'tags': ['math'],
        'email': 'a@b'
    };
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(current, anchor);
    assert arch is not None;
    assert getattr(arch, 'name') == 'ada';
    assert getattr(arch, 'tags') == ['math'];
    assert arch?.__jac_schema_repairs__ is None , (
        "no repairs should be recorded for an up-to-date document"
    );
}


test "schema_drop moves stored remains into the attic, not the void" {
    raw = _old_user_raw();
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert not hasattr(arch, 'legacy_bio');
    attic = arch?.__jac_attic__;
    assert isinstance(attic, dict) and 'legacy_bio' in attic , (
        f"dropped field missing from attic: {attic}"
    );
    assert attic['legacy_bio'].get('value') == 'wrote the first program';
}


test "attic survives a serialize round-trip" {
    raw = _old_user_raw();
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    out = Serializer.serialize(arch, include_type=True);
    assert isinstance(out, dict);
    attic = out.get('__jac_attic__');
    assert isinstance(attic, dict) and 'legacy_bio' in attic , (
        f"attic was lost on re-serialize: {out.keys()}"
    );
}


test "rules apply to subclass documents (inherited field history)" {
    raw = {
        '__type__': '_DriftAdmin',
        '__module__': getattr(_DriftAdmin, '__module__'),
        'username': 'grace',
        'tags': 'navy, compilers',
        'email': 'g@x',
        'level': 9
    };
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert getattr(arch, 'name') == 'grace';
    assert getattr(arch, 'tags') == ['navy', 'compilers'];
    assert getattr(arch, 'level') == 9;
}


# --- Unknown-field attic (replaces silent drop) ------------------------------
test "unknown stored fields are atticed instead of silently dropped" {
    raw = {
        '__type__': '_NoRules',
        '__module__': getattr(_NoRules, '__module__'),
        'name': 'ok',
        'stray_field': 'still here'
    };
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert getattr(arch, 'name') == 'ok';
    assert not hasattr(arch, 'stray_field');
    attic = arch?.__jac_attic__;
    assert isinstance(attic, dict) and 'stray_field' in attic , (
        "unknown fields must be preserved in the attic"
    );
    assert attic['stray_field'].get('value') == 'still here';
}


test "stored attic from a prior repair is carried through deserialize" {
    raw = {
        '__type__': '_NoRules',
        '__module__': getattr(_NoRules, '__module__'),
        'name': 'ok',
        '__jac_attic__': {'old_thing': {'value': 42, 'reason': 'dropped'}}
    };
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    attic = arch?.__jac_attic__;
    assert isinstance(attic, dict) and attic.get('old_thing', {}).get('value') == 42;
}


# --- Missing-field backfill ---------------------------------------------------
test "missing default_factory fields are backfilled on load" {
    raw = {
        '__type__': '_FactoryDefaults',
        '__module__': getattr(_FactoryDefaults, '__module__'),
        'name': 'x'
    };
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert hasattr(arch, 'items') , (
        "default_factory field missing from old doc must be backfilled, "
        "not left as a latent AttributeError"
    );
    assert getattr(arch, 'items') == [];
    assert getattr(arch, 'meta') == {};
}


test "backfilled factory defaults are per-instance, not shared" {
    raw = {
        '__type__': '_FactoryDefaults',
        '__module__': getattr(_FactoryDefaults, '__module__'),
        'name': 'x'
    };
    a1 = Serializer._deserialize_archetype(raw, NodeAnchor.__new__(NodeAnchor));
    a2 = Serializer._deserialize_archetype(dict(raw), NodeAnchor.__new__(NodeAnchor));
    assert a1 is not None and a2 is not None;
    getattr(a1, 'items').append('mine');
    assert getattr(a2, 'items') == [] , "factory backfill must not share state";
}


# --- Dual-write (rolling-deploy safety) ----------------------------------------
test "serialize dual-writes aliased old field names for old readers" {
    user = _DriftUser(name='ada', tags=['math'], email='a@b');
    out = Serializer.serialize(user, include_type=True);
    assert isinstance(out, dict);
    assert out.get('name') == 'ada';
    assert out.get('username') == 'ada' , (
        "aliased fields must dual-write the old stored name during the "
        f"transition window: {out.keys()}"
    );
}


test "serialize_fields dual-writes aliased fields on partial updates" {
    user = _DriftUser(name='ada', tags=[], email='a@b');
    anchor = user.__jac__;
    out = Serializer.serialize_fields(anchor, {'name'});
    assert out.get('name') == 'ada';
    assert out.get('username') == 'ada' , (
        "partial updates must refresh the shadow copy too, or old readers "
        "see stale values"
    );
}


test "loading a dual-written doc strips the shadow without repair churn" {
    raw = {
        '__type__': '_DriftUser',
        '__module__': getattr(_DriftUser, '__module__'),
        'name': 'ada',
        'username': 'ada',
        'tags': ['math'],
        'email': 'a@b'
    };
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert getattr(arch, 'name') == 'ada';
    assert not hasattr(arch, 'username');
    attic = arch?.__jac_attic__;
    assert not (isinstance(attic, dict) and 'username' in attic) , (
        "an equal shadow copy is by-design duplication, not unknown data"
    );
    assert arch?.__jac_schema_repairs__ is None , (
        "stripping an equal shadow must not trigger write-back churn"
    );
}


test "shadow conflict: new name wins, differing shadow is atticed" {
    raw = {
        '__type__': '_DriftUser',
        '__module__': getattr(_DriftUser, '__module__'),
        'name': 'ada',
        'username': 'ada-stale-write',
        'tags': ['math'],
        'email': 'a@b'
    };
    anchor = NodeAnchor.__new__(NodeAnchor);
    arch = Serializer._deserialize_archetype(raw, anchor);
    assert arch is not None;
    assert getattr(arch, 'name') == 'ada';
    attic = arch?.__jac_attic__;
    assert isinstance(attic, dict) and 'username' in attic , (
        "a differing shadow must be preserved, never destroyed"
    );
    assert attic['username'].get('value') == 'ada-stale-write';
    assert attic['username'].get('reason') == 'shadow-conflict';
    assert arch?.__jac_schema_repairs__ , (
        "conflict resolution must be recorded so backends persist it"
    );
}


# --- Kill switch ---------------------------------------------------------------
test "JAC_SCHEMA_REPAIR=off restores legacy behavior" {
    os.environ['JAC_SCHEMA_REPAIR'] = 'off';
    try {
        raw = _old_user_raw();
        anchor = NodeAnchor.__new__(NodeAnchor);
        arch = Serializer._deserialize_archetype(raw, anchor);
        assert arch is not None;
        # No rename, no upgrade, no attic: unknown fields drop silently.
        assert getattr(arch, 'name', '') == '' , "rename must not run when off";
        assert not hasattr(arch, 'username');
        assert arch?.__jac_attic__ is None;
        assert arch?.__jac_schema_repairs__ is None;
    } finally {
        os.environ.pop('JAC_SCHEMA_REPAIR', None);
    }
}


test "stored attic round-trips even when JAC_SCHEMA_REPAIR=off" {
    # The kill switch is the emergency rollback path; rolling back must
    # never destroy attic data a repair-mode deploy already preserved.
    os.environ['JAC_SCHEMA_REPAIR'] = 'off';
    try {
        raw = {
            '__type__': '_NoRules',
            '__module__': getattr(_NoRules, '__module__'),
            'name': 'ok',
            '__jac_attic__': {'old_thing': {'value': 42, 'reason': 'dropped'}}
        };
        anchor = NodeAnchor.__new__(NodeAnchor);
        arch = Serializer._deserialize_archetype(raw, anchor);
        assert arch is not None;
        attic = arch?.__jac_attic__;
        assert isinstance(attic, dict) and 'old_thing' in attic , (
            "attic must survive loads under off mode or the next save " "destroys it"
        );
        out = Serializer.serialize(arch, include_type=True);
        assert isinstance(out, dict)
        and 'old_thing' in (out.get('__jac_attic__') or {}) , "attic must survive a re-save under off mode";
    } finally {
        os.environ.pop('JAC_SCHEMA_REPAIR', None);
    }
}


test "JAC_SCHEMA_REPAIR=detect logs but does not mutate" {
    os.environ['JAC_SCHEMA_REPAIR'] = 'detect';
    try {
        raw = _old_user_raw();
        anchor = NodeAnchor.__new__(NodeAnchor);
        arch = Serializer._deserialize_archetype(raw, anchor);
        assert arch is not None;
        assert getattr(arch, 'name', '') == '' , "rename must not apply in detect mode";
        assert arch?.__jac_schema_repairs__ is None;
    } finally {
        os.environ.pop('JAC_SCHEMA_REPAIR', None);
    }
}


# --- Guard rails ----------------------------------------------------------------
test "builders raise outside an active collector" {
    raised = False;
    try {
        direct_schema_alias("a", stored="b");
    } except RuntimeError {
        raised = True;
    }
    assert raised , "schema builders must not be callable outside __jac_schema__";
}


test "validate_rules rejects alias whose new field is not declared" {
    rules = SchemaRules(owner="x.Y");
    rules.add_alias("not_a_field", "old");
    raised = False;
    try {
        validate_rules(rules, _NoRules);
    } except ValueError {
        raised = True;
    }
    assert raised , "alias target must be a declared field";
}


test "validate_rules rejects alias whose stored name is still declared" {
    rules = SchemaRules(owner="x.Y");
    rules.add_alias("name", "name");
    raised = False;
    try {
        validate_rules(rules, _NoRules);
    } except ValueError {
        raised = True;
    }
    assert raised , "stored (old) name colliding with a live field must be rejected";
}


test "validate_rules rejects two aliases targeting the same new field" {
    rules = SchemaRules(owner="x.Y");
    rules.add_alias("name", "username");
    rules.add_alias("name", "display_name");
    raised = False;
    try {
        validate_rules(rules, _NoRules);
    } except ValueError {
        raised = True;
    }
    assert raised , (
        "two aliases for one field must fail at registration, not produce "
        "fake shadow-conflicts at load time"
    );
}


test "validate_rules rejects drop of a still-declared field" {
    rules = SchemaRules(owner="x.Y");
    rules.add_drop("name");
    raised = False;
    try {
        validate_rules(rules, _NoRules);
    } except ValueError {
        raised = True;
    }
    assert raised , "schema_drop of a declared field must be rejected";
}
