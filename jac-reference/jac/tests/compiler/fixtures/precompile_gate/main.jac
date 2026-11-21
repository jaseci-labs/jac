import from "@jac/runtime" { jacIsLoggedIn }
import from feat.f0 { run_f0, gate_f0, Feature0 }
import from feat.f1 { run_f1, gate_f1, Feature1 }
import from feat.f2 { run_f2, gate_f2, Feature2 }
import from feat.f3 { run_f3, gate_f3, Feature3 }
import from feat.f4 { run_f4, gate_f4, Feature4 }
import from feat.f5 { run_f5, gate_f5, Feature5 }

def ready -> bool {
    return jacIsLoggedIn()
        and gate_f0()
        and gate_f1()
        and gate_f2()
        and gate_f3()
        and gate_f4()
        and gate_f5();
}

with entry {
    total = 0;
    total += run_f0();
    total += run_f1();
    total += run_f2();
    total += run_f3();
    total += run_f4();
    total += run_f5();
    print(total, ready());
}
