import os;


glob __all__ = ['humanize_error', 'show_tracebacks'];


def show_tracebacks -> bool {
    return os.environ.get('JAC_DEBUG', '').lower() not in ('', '0', 'false');
}


def _sqlstate(e: Exception) -> str {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and 'C' in arg {
            return str(arg.get('C') or '');
        }
    }
    return '';
}


def humanize_error(e: Exception) -> (tuple[str, (str | None)] | None) {
    import from jaclang.data.store { SessionConflictError }
    import from jaclang.data.pgwire { PgWireError }
    import from jaclang.server.net { PortInUseError }

    if isinstance(e, RecursionError) {
        return (
            'A construct in this program is nested too deeply for the compiler'
            ' to process.',
            'A long chain of operators nests one level per operator, so a chain'
            ' of a few thousand exhausts the working stack. Split it across'
            ' several statements, or build the value in a loop.'
        );
    }

    if isinstance(e, PortInUseError) {
        return (
            str(e),
            'A port you named is a contract, so jac fails instead of moving to'
            ' another one. Free the port (lsof -i :<port>), name a different'
            ' one, or drop --port to let jac pick the next free port.'
        );
    }

    if isinstance(e, SessionConflictError) {
        return (
            f"This project's database is in use: {e}",
            'Stop the other process (Ctrl+C in its terminal, or kill <pid>),'
            ' or rerun with --takeover to evict its database session.'
        );
    }
    if isinstance(e, PgWireError) {
        code = _sqlstate(e);
        if code == '55P03' {
            return (
                'Timed out waiting for a database lock held by another' ' session.',
                'Another jac process may be using this project. Stop it, or'
                ' rerun with --takeover to evict its database session.'
            );
        }
        if code == '53300' {
            return (
                'The Jac database is out of connections.',
                'A `jac test` run with the default worker fan-out can exhaust'
                ' the pool; set JAC_TEST_JOBS to a small number (e.g. 4) or'
                ' stop the other workload, then retry. If limits were raised'
                ' recently, restart the embedded Postgres to pick them up.'
            );
        }
        if code == '53200' {
            return (
                'The database ran out of predicate-lock memory (serializable'
                ' transaction tracking).',
                'A long-lived open transaction is usually pinning lock cleanup;'
                ' find it with ps (postgres: jac ... idle in transaction) and'
                ' stop that process, or restart the embedded Postgres.'
            );
        }
        if code in ('08006', '08003') {
            return (
                'Lost the connection to the Jac database mid-operation.',
                'Retry the command; the embedded server restarts on next use.'
            );
        }
    }
    return None;
}
