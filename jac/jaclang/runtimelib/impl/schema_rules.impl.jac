"""Implementation for schema_rules constructs."""

import threading;

# Collector state is thread-local so registrations from concurrent imports
# can't cross-pollinate; rule-collection itself is a stack to tolerate a
# __jac_schema__ that (indirectly) triggers another class registration.
glob _tls = threading.local(),
     # Definer-level rules keyed by "module.ClassName" of the defining class.
     _collected: dict[str, SchemaRules] = {},
     # MRO-merged view keyed by class object; cleared whenever a new
     # definer's rules are collected (class creation is rare and cheap).
     _merged_cache: dict = {};


impl SchemaRules.add_was(old_fqn: str) -> None {
    self.was_names.append(old_fqn);
}

impl SchemaRules.add_alias(new_name: str, stored_name: str) -> None {
    self.aliases.append(AliasRule(new_name=new_name, stored_name=stored_name));
}

impl SchemaRules.add_drop(field_name: str, until: (str | None) = None) -> None {
    self.drops.append(DropRule(field_name=field_name, until=until));
}

impl SchemaRules.add_upgrade(fn: Callable, when: (Callable | None) = None) -> None {
    self.upgrades.append(UpgradeRule(fn=fn, when=when));
}

impl SchemaRules.is_empty -> bool {
    return not (self.was_names or self.aliases or self.drops or self.upgrades);
}


impl _owner_key(cls: type) -> str {
    return f"{cls.__module__}.{cls.__name__}";
}


impl _require_collector -> SchemaRules {
    stack = _tls?.stack;
    if not stack {
        raise RuntimeError(
            "schema builders (schema_was/schema_alias/schema_drop/"
            "schema_upgrade) may only be called from inside an archetype's "
            "__jac_schema__ method during registration"
        );
    }
    return stack[-1];
}


impl schema_was(old_fqn: str) -> None {
    _require_collector().add_was(old_fqn);
}

impl schema_alias(new_name: str, stored: str) -> None {
    _require_collector().add_alias(new_name, stored);
}

impl schema_drop(field_name: str, until: (str | None) = None) -> None {
    _require_collector().add_drop(field_name, until);
}

impl schema_upgrade(fn: Callable, when: (Callable | None) = None) -> None {
    _require_collector().add_upgrade(fn, when);
}


impl collect_rules(cls: type) -> (SchemaRules | None) {
    if SCHEMA_HOOK not in cls.__dict__ {
        return None;
    }
    key = _owner_key(cls);
    rules = SchemaRules(owner=key);
    stack = _tls?.stack;
    if stack is None {
        stack = [];
        _tls.stack = stack;
    }
    stack.append(rules);
    try {
        getattr(cls, SCHEMA_HOOK)();
    } finally {
        stack.pop();
    }
    validate_rules(rules, cls);
    _collected[key] = rules;
    _merged_cache.clear();
    return rules;
}


impl merged_rules_for(cls: type) -> (SchemaRules | None) {
    if cls in _merged_cache {
        return _merged_cache[cls];
    }
    merged: (SchemaRules | None) = None;
    # Base-first so a subclass's own rules run after (and can build on) the
    # repairs its bases declared.
    for base in reversed(cls.__mro__) {
        definer_rules = _collected.get(_owner_key(base));
        if definer_rules is None {
            continue;
        }
        if merged is None {
            merged = SchemaRules(owner=_owner_key(cls));
        }
        merged.aliases.extend(definer_rules.aliases);
        merged.drops.extend(definer_rules.drops);
        merged.upgrades.extend(definer_rules.upgrades);
        # was_names intentionally excluded: definer-only (handled at
        # registration via Serializer.register_alias).
    }
    if merged is not None and merged.is_empty() {
        merged = None;
    }
    _merged_cache[cls] = merged;
    return merged;
}


impl validate_rules(rules: SchemaRules, cls: type) -> None {
    declared: set[str] = (
        {f.name for f in fields(cls)}
            if is_dataclass(cls)
            else set(getattr(cls, '__annotations__', {}).keys())
    );
    seen_stored: set[str] = set();
    seen_new: set[str] = set();
    for a in rules.aliases {
        if a.new_name not in declared {
            raise ValueError(
                f"{rules.owner}.__jac_schema__: schema_alias('{a.new_name}', "
                f"stored='{a.stored_name}') — '{a.new_name}' is not a "
                "declared field on the class"
            );
        }
        if a.stored_name in declared {
            raise ValueError(
                f"{rules.owner}.__jac_schema__: schema_alias('{a.new_name}', "
                f"stored='{a.stored_name}') — stored name "
                f"'{a.stored_name}' is still a declared field; a rename "
                "requires the old field to be gone"
            );
        }
        if a.stored_name in seen_stored {
            raise ValueError(
                f"{rules.owner}.__jac_schema__: duplicate schema_alias for "
                f"stored field '{a.stored_name}'"
            );
        }
        if a.new_name in seen_new {
            raise ValueError(
                f"{rules.owner}.__jac_schema__: multiple schema_alias rules "
                f"target field '{a.new_name}'; a field can have only one "
                "stored alias"
            );
        }
        seen_stored.add(a.stored_name);
        seen_new.add(a.new_name);
    }
    for d in rules.drops {
        if d.field_name in declared {
            raise ValueError(
                f"{rules.owner}.__jac_schema__: schema_drop('{d.field_name}') "
                "names a still-declared field; remove the `has` declaration "
                "first (schema_drop is about a field's stored remains)"
            );
        }
    }
    for u in rules.upgrades {
        if not callable(u.fn) {
            raise ValueError(
                f"{rules.owner}.__jac_schema__: schema_upgrade fn is not callable"
            );
        }
        if u.when is not None and not callable(u.when) {
            raise ValueError(
                f"{rules.owner}.__jac_schema__: schema_upgrade `when` is not callable"
            );
        }
    }
}


impl repair_mode -> str {
    val = os.environ.get('JAC_SCHEMA_REPAIR', 'repair').strip().lower();
    return val if val in ('repair', 'detect', 'off') else 'repair';
}


impl apply_rules(data: dict, rules: SchemaRules) -> tuple {
    steps: list[str] = [];
    changed = False;
    out = dict(data);
    for a in rules.aliases {
        if a.stored_name not in out {
            continue;
        }
        if a.new_name not in out {
            out[a.new_name] = out.pop(a.stored_name);
            steps.append(f"rename {a.stored_name} -> {a.new_name}");
            changed = True;
        } else {
            # Both keys present: a dual-written document, not drift. An
            # equal shadow strips silently (it regenerates on save, so no
            # step => no write-back churn). A differing shadow means an
            # old-version writer raced an upgraded doc: the new name wins
            # deterministically and the conflicting value is preserved.
            shadow = out.pop(a.stored_name);
            changed = True;
            if shadow != out[a.new_name] {
                attic_src = out.get(ATTIC_KEY);
                attic = dict(attic_src) if isinstance(attic_src, dict) else {};
                attic[a.stored_name] = {'value': shadow, 'reason': 'shadow-conflict'};
                out[ATTIC_KEY] = attic;
                steps.append(f"shadow-conflict {a.stored_name} (kept {a.new_name})");
            }
        }
    }
    for u in rules.upgrades {
        fn_name = getattr(u.fn, '__name__', '<fn>');
        try {
            # Predicates get a copy too (like the callback below): rules
            # must never observe or mutate the engine's in-flight dict.
            if u.when is not None and not u.when(dict(out)) {
                continue;
            }
            # The callback gets a copy and must return the replacement dict;
            # a raise or a non-dict return leaves `out` untouched.
            result = u.fn(dict(out));
            if isinstance(result, dict) {
                out = result;
                steps.append(f"upgrade {fn_name}");
                changed = True;
            } else {
                logger.warning(
                    f"schema_upgrade {rules.owner}.{fn_name} returned "
                    f"{type(result).__name__} instead of dict; skipped"
                );
            }
        } except Exception as e {
            logger.warning(
                f"schema_upgrade {rules.owner}.{fn_name} raised "
                f"{type(e).__name__}: {e}; skipped"
            );
        }
    }
    for d in rules.drops {
        if d.field_name in out {
            attic_src = out.get(ATTIC_KEY);
            attic = dict(attic_src) if isinstance(attic_src, dict) else {};
            attic[d.field_name] = {'value': out.pop(d.field_name), 'reason': 'dropped'};
            out[ATTIC_KEY] = attic;
            steps.append(f"attic {d.field_name}");
            changed = True;
        }
    }
    return ((out, steps) if changed else (data, steps));
}
