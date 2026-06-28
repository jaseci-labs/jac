glob _CLOCK_REALTIME: int = 0,
     _CLOCK_MONOTONIC: int = 1;

impl NaIRGenPass._emit_clock_gettime(clock_id: int) -> tuple {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    timespec_ty = ir.LiteralStructType([i64, i64]);
    ts = self.builder.alloca(timespec_ty, name="time.ts");
    fn = self._get_or_declare_extern(
        "clock_gettime", i32, [i32, timespec_ty.as_pointer()]
    );
    self.builder.call(fn, [ir.Constant(i32, clock_id), ts], name="time.clk");
    sec_ptr = self.builder.gep(
        ts, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="time.sec.ptr"
    );
    nsec_ptr = self.builder.gep(
        ts, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="time.nsec.ptr"
    );
    sec = self.builder.load(sec_ptr, name="time.sec");
    nsec = self.builder.load(nsec_ptr, name="time.nsec");
    return (sec, nsec);
}

impl NaIRGenPass._emit_time_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    f64 = ir.DoubleType();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    billion = ir.Constant(i64, 1000000000);

    _float_clocks: dict[str, int] = {
        "time": _CLOCK_REALTIME,
        "monotonic": _CLOCK_MONOTONIC,
        "perf_counter": _CLOCK_MONOTONIC,

    };
    if name in _float_clocks {
        (sec, nsec) = self._emit_clock_gettime(_float_clocks[name]);
        sec_f = self.builder.sitofp(sec, f64, name="time.sec.f");
        nsec_f = self.builder.sitofp(nsec, f64, name="time.nsec.f");
        scaled = self.builder.fmul(nsec_f, ir.Constant(f64, 1e-9), name="time.nsec.s");
        return self.builder.fadd(sec_f, scaled, name=f"time.{name}");
    }

    _ns_clocks: dict[str, int] = {
        "time_ns": _CLOCK_REALTIME,
        "monotonic_ns": _CLOCK_MONOTONIC,
        "perf_counter_ns": _CLOCK_MONOTONIC,

    };
    if name in _ns_clocks {
        (sec, nsec) = self._emit_clock_gettime(_ns_clocks[name]);
        scaled = self.builder.mul(sec, billion, name="time.sec.ns");
        return self.builder.add(scaled, nsec, name=f"time.{name}");
    }

    if name == "sleep" {
        params = nd.params or [];
        if not params {
            return None;
        }
        secs = self._codegen_expr(params[0]);
        if secs is None {
            return None;
        }
        secs = self._coerce_type(secs, f64);
        whole = self.builder.fptosi(secs, i64, name="sleep.sec");
        whole_f = self.builder.sitofp(whole, f64, name="sleep.sec.f");
        frac = self.builder.fsub(secs, whole_f, name="sleep.frac");
        frac_ns_f = self.builder.fmul(
            frac, ir.Constant(f64, 1e9), name="sleep.frac.ns.f"
        );
        frac_ns = self.builder.fptosi(frac_ns_f, i64, name="sleep.frac.ns");
        timespec_ty = ir.LiteralStructType([i64, i64]);
        req = self.builder.alloca(timespec_ty, name="sleep.req");
        sec_ptr = self.builder.gep(
            req, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sleep.sec.ptr"
        );
        nsec_ptr = self.builder.gep(
            req, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="sleep.nsec.ptr"
        );
        self.builder.store(whole, sec_ptr);
        self.builder.store(frac_ns, nsec_ptr);
        nullts = ir.Constant(timespec_ty.as_pointer(), None);
        fn = self._get_or_declare_extern(
            "nanosleep", i32, [timespec_ty.as_pointer(), timespec_ty.as_pointer()]
        );
        self.builder.call(fn, [req, nullts], name="time.sleep");
        return None;
    }

    return None;
}
