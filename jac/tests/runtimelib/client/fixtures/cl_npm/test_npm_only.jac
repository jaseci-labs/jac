"""Client test whose only foreign dependency is an npm package.

Nothing here talks to a backend, so the module never imports `@jac/runtime`.
The runner still has to neutralize the `fake-npm-pkg` import, because the
harness runs in a sealed temp dir with no `node_modules` for bun to resolve
it against.
"""

import from "fake-npm-pkg" { helper }

test "an npm import is neutralized without a backend" {
    # `helper` resolves to the universal Proxy stub; calling it must not throw.
    helper();
    assert 1 + 1 == 2;
}
