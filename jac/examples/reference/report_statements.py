from __future__ import annotations
from jaclang.lib import Root, Walker, disengage, on_entry, log_report, root, spawn


class Reporter(Walker):

    @on_entry
    def process(self, here: Root) -> None:
        log_report(42)
        log_report("hello")
        log_report(10 + 20)
        x = 100
        log_report(x)
        log_report([1, 2, 3])
        log_report({"key": "value", "number": 123})
        log_report({"result": 5 * 10, "status": "ok"})
        disengage(self)
        return


w = Reporter()
spawn(root(), w)
