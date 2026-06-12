"""Token-aware shell allow-list matcher (DRAFT STUB) — finding #3.

Current shell_plugin matches only pattern_argv[0], so `allow = ["git log"]`
silently permits ALL git subcommands (the " log" is ignored). This matches each
pattern token against the corresponding argv token, with a trailing "*" meaning
"any remaining args."

Backward compatible:
  "echo *"     -> any echo invocation        (trailing wildcard)
  "git *"      -> any git invocation          (trailing wildcard)
  "git log"    -> ONLY `git log`              (was: any git — the bug)
  "git log *"  -> `git log` with any args
"""
import fnmatch;
import shlex;


"""True iff argv is permitted by pattern_argv."""
def _pattern_matches(pattern_argv: list, argv: list) -> bool {
    for (i, ptok) in enumerate(pattern_argv) {
        # Trailing "*" allows any remaining args.
        if ptok == "*" and i == len(pattern_argv) - 1 {
            return True;
        }
        if i >= len(argv) {
            return False;
        }
        if not fnmatch.fnmatch(argv[i], ptok) {
            return False;
        }
    }
    # Pattern exhausted with no trailing wildcard: argv must match exactly.
    return len(argv) == len(pattern_argv);
}


"""Drop-in replacement for the matching loop in ShellPlugin._exec."""
def is_allowed(allow: list, argv: list) -> bool {
    for pattern in allow {
        pattern_argv = shlex.split(pattern);
        if not pattern_argv {
            continue;
        }
        if _pattern_matches(pattern_argv, argv) {
            return True;
        }
    }
    return False;
}


# ---- Test the surprising case the current suite misses ----
# (add to tests/test_integration.jac once promoted)
test "shell allow-list does not silently widen subcommands" {
    # "git log" must NOT permit "git push"
    assert is_allowed(["git log"], ["git", "log"]) == True;
    assert is_allowed(["git log"], ["git", "push"]) == False;
    # trailing wildcard still works
    assert is_allowed(["git *"], ["git", "push"]) == True;
    assert is_allowed(["echo *"], ["echo", "hi"]) == True;
    # exact match, extra args rejected unless wildcarded
    assert is_allowed(["ls"], ["ls", "-la"]) == False;
    assert is_allowed(["ls *"], ["ls", "-la"]) == True;
}
