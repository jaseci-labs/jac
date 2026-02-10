"""CLI handlers for client targets.

Provides a class-based handler for all client target CLI operations (build, setup, start, dev).
Uses the BuildContext/BuildResult architecture and delegates to targets via the factory.
"""
import from pathlib { Path }
import from jaclang.cli.command { HookContext }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import from .types { ClientTargetType, BuildContext, BuildResult }
import from .factory { get_target, get_available_target_names }

# Error message constants
glob ERR_NO_PROJECT = "No jac.toml found. Run 'jac create' to create a project.",
     ERR_NO_ENTRY = "No entry file specified. Use: jac <command> <file>",
     ERR_NO_TARGET = "No target specified. Use: jac setup <target>";

"""CLI handler for client target operations.

This class encapsulates all CLI handling logic for build targets,
providing a clean OOP interface for the CLI to use. It follows the
same patterns as other handler classes in the codebase.

Usage:
    handler = TargetCLIHandler();
    handler.handle_build(ctx);  # For build command
    handler.handle_setup(ctx);  # For setup command
    handler.handle_start(ctx);  # For start command
"""
class TargetCLIHandler {
    """Operation type constants."""
    with entry {
        OP_BUILD = "build";
        OP_DEV = "dev";
        OP_START = "start";
        OP_SETUP = "setup";
    }

    """Handle build command - delegates entirely to target."""
    def handle_build(self: TargetCLIHandler, ctx: HookContext) -> None {
        target_name = ctx.get_arg("client", "web");
        build_ctx = self._extract_context(ctx, target_name);
        if not build_ctx {
            return;
        }

        result = self._execute_lifecycle(ctx, build_ctx, TargetCLIHandler.OP_BUILD);
        if result {
            self._handle_result(
                ctx, result, f"Build complete for '{target_name}' target"
            );
        }
    }

    """Handle setup command - delegates entirely to target."""
    def handle_setup(self: TargetCLIHandler, ctx: HookContext) -> None {
        target_name = ctx.get_arg("target", None);
        if not target_name {
            self._fail(ctx, ERR_NO_TARGET, self._get_available_targets_hint());
            return;
        }

        config = get_config();
        if not config {
            self._fail(ctx, ERR_NO_PROJECT);
            return;
        }

        project_dir = config.project_root or Path.cwd();

        try {
            target_type = ClientTargetType(target_name);
        } except ValueError {
            self._fail(
                ctx,
                f"Unknown target: '{target_name}'",
                self._get_available_targets_hint()
            );
            return;
        }

        # Create minimal context for setup (no entry file needed)
        build_ctx = BuildContext(
            target_type=target_type,
            entry_file=project_dir / "main.jac",
            project_dir=project_dir,
            config=config
        );

        result = self._execute_lifecycle(ctx, build_ctx, TargetCLIHandler.OP_SETUP);
        if result {
            self._handle_result(
                ctx, result, f"Setup complete for '{target_name}' target"
            );
        }
    }

    """Handle start command - routes to dev or start based on mode."""
    def handle_start(self: TargetCLIHandler, ctx: HookContext) -> None {
        target_name = ctx.get_arg("client", "web");
        build_ctx = self._extract_context(ctx, target_name);
        if not build_ctx {
            return;
        }

        operation = TargetCLIHandler.OP_DEV
        if build_ctx.dev_mode
        else TargetCLIHandler.OP_START;
        result = self._execute_lifecycle(ctx, build_ctx, operation);

        if result {
            # Web target returns success but lets main jac start continue
            # Check if result indicates passthrough (no output_path means passthrough)
            if result.success and not result.output_path and not result.error {
                return;  # Passthrough to main jac start

            }
            self._handle_result(ctx, result);
        }
    }

    # -------------------------------------------------------------------------
    # Private helper methods
    # -------------------------------------------------------------------------
    """Cancel CLI execution with specified error code."""
    def _cancel_with_code(
        self: TargetCLIHandler, ctx: HookContext, code: int = 1
    ) -> None {
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", code);
    }

    """Show error message and cancel execution."""
    def _fail(
        self: TargetCLIHandler, ctx: HookContext, message: str, hint: str | None = None
    ) -> None {
        console.error(message);
        if hint {
            console.print(hint, style="muted");
        }
        self._cancel_with_code(ctx, 1);
    }

    """Get hint string showing available targets."""
    def _get_available_targets_hint(self: TargetCLIHandler) -> str {
        return f"Available targets: {', '.join(get_available_target_names())}";
    }

    """Extract build context from CLI hook context.

    Returns BuildContext on success, None on error (with error already printed).
    """
    def _extract_context(
        self: TargetCLIHandler, ctx: HookContext, target_name: str = "web"
    ) -> BuildContext | None {
        config = get_config();
        if not config {
            self._fail(ctx, ERR_NO_PROJECT);
            return None;
        }

        entry_file = ctx.get_arg("filename", None) or config.entry_point;
        if not entry_file {
            self._fail(ctx, ERR_NO_ENTRY);
            return None;
        }

        entry_path = Path(entry_file);
        project_dir = config.project_root or Path.cwd();
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }

        try {
            target_type = ClientTargetType(target_name);
        } except ValueError {
            self._fail(
                ctx,
                f"Unknown target: '{target_name}'",
                self._get_available_targets_hint()
            );
            return None;
        }

        return BuildContext.from_args(
            target_type=target_type,
            entry_file=entry_path,
            project_dir=project_dir,
            config=config,
            port=ctx.get_arg("port", 8000),
            platform=ctx.get_arg("platform", None),
            dev_mode=ctx.get_arg("dev", False),
            verbose=ctx.get_arg("verbose", False)
        );
    }

    """Handle result from target operation."""
    def _handle_result(
        self: TargetCLIHandler,
        ctx: HookContext,
        result: BuildResult,
        success_msg: str = ""
    ) -> None {
        if result.success {
            if success_msg {
                console.success(success_msg);
            }
            if result.output_path {
                console.print(f"  Output: {result.output_path}", style="muted");
            }
            for warning in result.warnings {
                console.warning(warning);
            }
            self._cancel_with_code(ctx, 0);
        } else {
            self._fail(ctx, result.error or "Operation failed");
        }
    }

    """Execute target lifecycle with validation and hooks.

    This method orchestrates the full lifecycle:
    1. Get target from factory
    2. Validate context
    3. Execute pre-hooks (for build)
    4. Execute operation
    5. Execute post-hooks (for build)
    """
    def _execute_lifecycle(
        self: TargetCLIHandler,
        ctx: HookContext,
        build_ctx: BuildContext,
        operation: str
    ) -> BuildResult | None {
        try {
            target = get_target(build_ctx.target_type.value);

            # Skip validation for setup (setup creates the files validation checks for)
            if operation != TargetCLIHandler.OP_SETUP {
                validation = target.validate(build_ctx);
                if not validation.success {
                    self._handle_result(ctx, validation);
                    return None;
                }
            }

            # Execute operation
            if operation == TargetCLIHandler.OP_BUILD {
                pre_result = target.pre_build(build_ctx);
                if not pre_result.success {
                    self._handle_result(ctx, pre_result);
                    return None;
                }
                result = target.build(build_ctx);
                target.post_build(build_ctx, result);
            } elif operation == TargetCLIHandler.OP_DEV {
                result = target.dev(build_ctx);
            } elif operation == TargetCLIHandler.OP_START {
                result = target.start(build_ctx);
            } elif operation == TargetCLIHandler.OP_SETUP {
                result = target.setup(build_ctx);
            } else {
                return BuildResult.fail(f"Unknown operation: {operation}");
            }

            return result;
        } except ValueError as e {
            self._fail(ctx, str(e));
            return None;
        } except Exception as e {
            self._fail(ctx, f"{operation.capitalize()} failed: {e}");
            return None;
        }
    }
}
