import from "@jac/runtime" { jacIsLoggedIn }
import from core.gamma { total_gamma, name_gamma }
import from core.delta { total_delta, name_delta }
import from core.alpha { total_alpha, name_alpha }

def run_f2 -> int {
    r = 0;
    r += total_gamma(2);
    r += total_delta(2);
    r += total_alpha(2);
    return r;
}

def label_f2 -> str {
    return name_gamma(2) + " " + name_delta(2) + " " + name_alpha(2);
}

def gate_f2 -> bool {
    return jacIsLoggedIn() and run_f2() > 0;
}

obj Feature2 {
    has labels: list[str] = [];

    def count -> int {
        return len(self.labels);
    }
}
