"""Backend entry point for Jac IDE application."""

import from dotenv { load_dotenv }
import from services.jaccoder_adapter { init_jaccoder_web_mode }
import from services.preview_manager { init_preview_warmpool }
import from services.ideServer {
        env_ops,
        community_ops,
        community_submit,
        me,
        Router,
        template_ops,
        project_ops,
        version_ops,
        ide_file_ops,
        preview_control,
        preview_screenshot,
        ide_preview_stream,
        ai_chat,
        claude_chat,
        git_ops,
        deploy_ops,
        lsp_stream,
        terminal_stream,
        claude_history,
        github_ops
    }

with entry {
    load_dotenv();
    init_jaccoder_web_mode();
    init_preview_warmpool();
}

# Client-side code
cl {
    import from .frontend { app as ClientApp }

    def:pub app() -> Any {
        return <ClientApp />;
    }
}
