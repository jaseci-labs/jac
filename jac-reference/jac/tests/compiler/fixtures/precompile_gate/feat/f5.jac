import from "@jac/runtime" { jacIsLoggedIn }
import from core.beta { total_beta, name_beta }
import from core.gamma { total_gamma, name_gamma }
import from core.delta { total_delta, name_delta }

def run_f5 -> int {
    r = 0;
    r += total_beta(5);
    r += total_gamma(5);
    r += total_delta(5);
    return r;
}

def label_f5 -> str {
    return name_beta(5) + " " + name_gamma(5) + " " + name_delta(5);
}

def gate_f5 -> bool {
    return jacIsLoggedIn() and run_f5() > 0;
}

obj Feature5 {
    has labels: list[str] = [];

    def count -> int {
        return len(self.labels);
    }
}
