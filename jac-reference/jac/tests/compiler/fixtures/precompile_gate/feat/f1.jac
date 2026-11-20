import from "@jac/runtime" { jacIsLoggedIn }
import from core.beta { total_beta, name_beta }
import from core.gamma { total_gamma, name_gamma }
import from core.delta { total_delta, name_delta }

def run_f1 -> int {
    r = 0;
    r += total_beta(1);
    r += total_gamma(1);
    r += total_delta(1);
    return r;
}

def label_f1 -> str {
    return name_beta(1) + " " + name_gamma(1) + " " + name_delta(1);
}

def gate_f1 -> bool {
    return jacIsLoggedIn() and run_f1() > 0;
}

obj Feature1 {
    has labels: list[str] = [];

    def count -> int {
        return len(self.labels);
    }
}
