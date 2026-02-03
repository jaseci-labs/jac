"""Dictionary type codegen and operations."""
"""Integer power operation using loop-based exponentiation."""
impl NaIRGenPass._codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value {
    # Simple loop-based integer exponentiation
    # result = 1; for i in range(exp): result *= base
    i64 = ir.IntType(64);
    func = self.builder.function;
    # Allocate result and counter
    result_alloca = self._entry_alloca(i64, "pow.result");
    counter_alloca = self._entry_alloca(i64, "pow.counter");
    self.builder.store(ir.Constant(i64, 1), result_alloca);
    self.builder.store(ir.Constant(i64, 0), counter_alloca);
    # Basic blocks
    cond_bb = func.append_basic_block(name="pow.cond");
    body_bb = func.append_basic_block(name="pow.body");
    end_bb = func.append_basic_block(name="pow.end");
    self.builder.branch(cond_bb);
    # Condition: counter < exp
    self.builder.position_at_end(cond_bb);
    counter = self.builder.load(counter_alloca, name="pow.i");
    cmp = self.builder.icmp_signed("<", counter, exp, name="pow.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    # Body: result *= base; counter++
    self.builder.position_at_end(body_bb);
    cur_result = self.builder.load(result_alloca, name="pow.cur");
    new_result = self.builder.mul(cur_result, base, name="pow.mul");
    self.builder.store(new_result, result_alloca);
    cur_counter = self.builder.load(counter_alloca, name="pow.ci");
    next_counter = self.builder.add(cur_counter, ir.Constant(i64, 1), name="pow.inc");
    self.builder.store(next_counter, counter_alloca);
    self.builder.branch(cond_bb);
    # End: return result
    self.builder.position_at_end(end_bb);
    return self.builder.load(result_alloca, name="pow.final");
}
