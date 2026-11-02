"""Handlers in CPython's tail-call shape: preserve_none C definitions that
dispatch to each other through a preserve_none function-pointer table."""
import from c {
    @__preserve_none
    obj StepTable {
        has step: Callable[[ptr[i64], i64, i64], i64] = 0;
    }  glob:priv step_table: StepTable = StepTable(); glob:priv step_calls: i64 = 0; @__preserve_none
    def pn_count(acc: ptr[i64], n: i64, total: i64) -> i64 {
        if n == 0 {
            return total;
        }
        acc.view(1)[0] = acc.view(1)[0] + 1;
        table = ptr[StepTable](addressof(step_table));
        return tail table.view(1)[0].step(acc, n - 1, total + n);
    }
}

def:pub pn_run(n: i64) -> i64 {
    table = ptr[StepTable](addressof(step_table));
    table.view(1)[0].step = pn_count;
    counter = ptr[i64](addressof(step_calls));
    counter.view(1)[0] = 0;
    total = table.view(1)[0].step(counter, n, 0);
    return total * 1000 + counter.view(1)[0];
}
