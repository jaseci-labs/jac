import from "@jac/runtime" { jacIsLoggedIn }
import from core.alpha { total_alpha, name_alpha }
import from core.beta { total_beta, name_beta }
import from core.gamma { total_gamma, name_gamma }

def run_f0 -> int {
    r = 0;
    r += total_alpha(0);
    r += total_beta(0);
    r += total_gamma(0);
    return r;
}

def label_f0 -> str {
    return name_alpha(0) + " " + name_beta(0) + " " + name_gamma(0);
}

def gate_f0 -> bool {
    return jacIsLoggedIn() and run_f0() > 0;
}

obj Feature0 {
    has labels: list[str] = [];

    def count -> int {
        return len(self.labels);
    }
}
