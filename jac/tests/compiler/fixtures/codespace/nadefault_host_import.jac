"""Imports a jaclang host module, which is never compiled native."""
import from jaclang.cli.workpool { pool_available }

def helper -> bool {
    return pool_available();
}
