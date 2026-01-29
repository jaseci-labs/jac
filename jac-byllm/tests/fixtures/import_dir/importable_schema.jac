"""Fixture with function that can be imported - module name ends with 'a'."""

import from byllm.lib { MockLLM }
import from jaclang { JacRuntime }

obj ImportedData {
    has name: str;
}

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": [ImportedData(name="test_import")], "verbose": False}
);

def get_imported_data(txt: str) -> ImportedData by llm();

# Helper to verify MTIR can be retrieved at runtime
def verify_mtir_retrieval() -> bool {
    # Try to get MTIR for get_imported_data using JacRuntime
    # The scope should be based on this module's path
    try {
        mtir_map = JacRuntime.program.mtir_map if JacRuntime.program else {};
        # Find the scope containing get_imported_data
        matching_scopes = [
            scope for scope in mtir_map.keys() if "get_imported_data" in scope
        ];
        if len(matching_scopes) > 0 {
            print(f"MTIR_TEST: Found scopes: {matching_scopes}");
            # Verify the scope contains the full module name (importable_schema, not importable_schem)
            has_correct_scope = False;
            for scope in matching_scopes {
                if "importable_schema" in scope {
                    has_correct_scope = True;
                    break;
                }
            }
            print(f"MTIR_TEST: Has correct scope with 'importable_schema': {has_correct_scope}");
            return has_correct_scope;
        } else {
            print(f"MTIR_TEST: No scopes found containing 'get_imported_data'");
            print(f"MTIR_TEST: Available scopes: {list(mtir_map.keys())}");
            return False;
        }
    } except Exception as e {
        print(f"MTIR_TEST: Error: {e}");
        return False;
    }
}
