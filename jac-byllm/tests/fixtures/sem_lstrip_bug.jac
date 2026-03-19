"""Regression test for lstrip('sem.') bug (issue #5233).

lstrip('sem.') strips individual characters {s, e, m, .}, corrupting
function names that start with those letters.  The sem string is then
silently dropped because the symbol-table lookup fails.
"""
import from byllm.lib { MockLLM }
import from jaclang { JacRuntimeInterface as Jac }

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": ["r1", "r2", "r3", "r4"]}
);

# Function starting with 's' — broken by lstrip
def summarize_text(text: str) -> str by llm();
sem summarize_text = "Summarize the given text into a concise summary.";

# Function starting with 'e' — broken by lstrip
def evaluate_score(text: str) -> str by llm();
sem evaluate_score = "Evaluate and return a numeric score for the text.";

# Function starting with 'm' — broken by lstrip
def merge_results(text: str) -> str by llm();
sem merge_results = "Merge multiple results into a single combined output.";

# Function starting with 'f' — NOT broken by lstrip (control)
def fetch_data(text: str) -> str by llm();
sem fetch_data = "Fetch data from the remote source.";

with entry {
    # Retrieve FunctionInfo from the MTIR map and print semstr
    for name in ["summarize_text", "evaluate_score", "merge_results", "fetch_data"] {
        info = Jac.get_mtir_from_map(f"sem_lstrip_bug.{name}");
        if info is not None {
            print(f"MTIR_{name}: {info.semstr}");
        } else {
            print(f"MTIR_{name}: MISSING");
        }
    }
}
