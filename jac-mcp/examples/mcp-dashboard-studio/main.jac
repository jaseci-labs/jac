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
    search_docs_service,
    jac_to_js_service,
    jac_to_py_service,
    run_jac_service,
    lint_jac_service,
    graph_visualize_service,
    list_commands_service,
    get_command_service,
    execute_command_service,
    understand_jac_and_jaseci_service,
    get_resource_service
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
                        str(check["message"])
                            if "message" in check
                            else "unknown error"
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

walker:pub jac_to_js {
    has code: str,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("jac_to_js");
            disengage;
        }
        report jac_to_js_service(self.code);
    }
}

walker:pub jac_to_py {
    has code: str,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("jac_to_py");
            disengage;
        }
        report jac_to_py_service(self.code);
    }
}

walker:pub run_jac {
    has code: str,
        entrypoint: str = "",
        timeout: int = 30,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("run_jac");
            disengage;
        }
        report run_jac_service(self.code, self.entrypoint, self.timeout);
    }
}

walker:pub lint_jac {
    has code: str,
        auto_fix: bool = False,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("lint_jac");
            disengage;
        }
        report lint_jac_service(self.code, self.auto_fix);
    }
}

walker:pub graph_visualize {
    has code: str,
        output: dict = {};

    can run with Root entry {
        if not self.code.strip() {
            report empty_code_response("graph_visualize");
            disengage;
        }
        report graph_visualize_service(self.code);
    }
}

walker:pub list_commands {
    has output: dict = {};

    can run with Root entry {
        report list_commands_service();
    }
}

walker:pub get_command {
    has name: str,
        output: dict = {};

    can run with Root entry {
        if not self.name.strip() {
            report {
                "ok": False,
                "tool": "get_command",
                "data": {},
                "error": {"message": "Command name cannot be empty."}
            };
            disengage;
        }
        report get_command_service(self.name);
    }
}

walker:pub execute_command {
    has command: str,
        args: list[str] = [],
        timeout: int = 30,
        output: dict = {};

    can run with Root entry {
        if not self.command.strip() {
            report {
                "ok": False,
                "tool": "execute_command",
                "data": {},
                "error": {"message": "Command cannot be empty."}
            };
            disengage;
        }
        report execute_command_service(self.command, self.args, self.timeout);
    }
}

walker:pub understand_jac_and_jaseci {
    has output: dict = {};

    can run with Root entry {
        report understand_jac_and_jaseci_service();
    }
}

walker:pub get_resource {
    has uri: str,
        output: dict = {};

    can run with Root entry {
        if not self.uri.strip() {
            report {
                "ok": False,
                "tool": "get_resource",
                "data": {},
                "error": {"message": "URI is required"}
            };
            disengage;
        }
        report get_resource_service(self.uri);
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
