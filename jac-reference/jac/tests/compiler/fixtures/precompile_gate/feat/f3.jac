import from "@jac/runtime" { jacIsLoggedIn }
import from core.delta { total_delta, name_delta }
import from core.alpha { total_alpha, name_alpha }
import from core.beta { total_beta, name_beta }

def run_f3 -> int {
    r = 0;
    r += total_delta(3);
    r += total_alpha(3);
    r += total_beta(3);
    return r;
}

def label_f3 -> str {
    return name_delta(3) + " " + name_alpha(3) + " " + name_beta(3);
}

def gate_f3 -> bool {
    return jacIsLoggedIn() and run_f3() > 0;
}

obj Feature3 {
    has labels: list[str] = [];

    def count -> int {
        return len(self.labels);
    }
}
