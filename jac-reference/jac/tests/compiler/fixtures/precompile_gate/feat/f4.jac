import from "@jac/runtime" { jacIsLoggedIn }
import from core.alpha { total_alpha, name_alpha }
import from core.beta { total_beta, name_beta }
import from core.gamma { total_gamma, name_gamma }

def run_f4 -> int {
    r = 0;
    r += total_alpha(4);
    r += total_beta(4);
    r += total_gamma(4);
    return r;
}

def label_f4 -> str {
    return name_alpha(4) + " " + name_beta(4) + " " + name_gamma(4);
}

def gate_f4 -> bool {
    return jacIsLoggedIn() and run_f4() > 0;
}

obj Feature4 {
    has labels: list[str] = [];

    def count -> int {
        return len(self.labels);
    }
}
