"""The contract of the `limits` abstraction: `Limits`, the interface of the
plugin that counts uses against a limit."""

import from common.contract { Host }

"""What counts uses: the interface of the `limits` abstraction's plugins.
`open` is the first thing asked of it, given the program it runs in.
`consume` counts a use of `scope` by `actor`, and gives 0 while that is
within `limit` uses in `seconds`, else the seconds until it is."""
obj Limits {
    def open(host: dyn Host) abst;
    def consume(scope: str, actor: str, limit: int, seconds: int) -> int abst;
}
