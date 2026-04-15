cl import "./styles/main.css";
import from backend.service {
    set_server_url,
    ping_endpoint,
    validate_jac_service,
    check_syntax_service,
    format_jac_service,
    py_to_jac_service,
    get_ast_service,
    explain_error_service,
    list_examples_service,
    get_example_service,
    search_docs_service
}

import from backend.utils {
    empty_code_response,
    empty_error_message_response,
    empty_name_response,
    empty_query_response
}

# Connection walker
walker:pub set_mcp_server {
    has server_url: str;

    can run with Root entry {
        check = ping_endpoint(self.server_url);
        if not check["ok"] {
            report {
                "ok": False,
                "tool": "set_mcp_server",
                "data": {},
                "error": {
                    "message": "Endpoint unreachable: " + (
                        str(check["message"]) if "message" in check else "unknown error"
                    )
                }
            };
            disengage;
        }
        set_server_url(self.server_url);
        report {
            "ok": True,
            "tool": "set_mcp_server",
            "data": {"server_url": self.server_url},
            "error": {}
        };
    }
}

# Tool walkers
walker:pub validate_jac {
    has code: str,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("validate_jac");
            disengage;
        }
        report validate_jac_service(self.code);
    }
}

walker:pub check_syntax {
    has code: str,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("check_syntax");
            disengage;
        }
        report check_syntax_service(self.code);
    }
}

walker:pub format_jac {
    has code: str,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("format_jac");
            disengage;
        }
        report format_jac_service(self.code);
    }
}

walker:pub py_to_jac {
    has code: str,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("py_to_jac");
            disengage;
        }
        report py_to_jac_service(self.code);
    }
}

walker:pub get_ast {
    has code: str,
        format: str = "tree",
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("get_ast");
            disengage;
        }
        report get_ast_service(self.code, self.format);
    }
}

walker:pub explain_error {
    has error_message: str,
        output: dict = {};

    can run with Root entry {
        if not self.error_message.strip() {
            report empty_error_message_response();
            disengage;
        }
        report explain_error_service(self.error_message);
    }
}

walker:pub list_examples {
    has output: dict = {};

    can run with Root entry {
        report list_examples_service();
    }
}

walker:pub get_example {
    has name: str,
        output: dict = {};

    can run with Root entry {
        if not self.name.strip() {
            report empty_name_response();
            disengage;
        }
        report get_example_service(self.name);
    }
}

walker:pub search_docs {
    has query: str,
        output: dict = {};

    can run with Root entry {
        if not self.query.strip() {
            report empty_query_response();
            disengage;
        }
        report search_docs_service(self.query);
    }
}

# Frontend entry
cl {
    import from ".frontend.Dashboard" { DashboardPage }

    def:pub app -> JsxElement {
        return
            <DashboardPage/>;
    }
}
