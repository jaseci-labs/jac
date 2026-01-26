"""File covering plugin implementation."""
import os;
import pathlib;
import from dotenv { load_dotenv }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind, CommandPriority, HookContext }
import from jaclang.cli.console { console }
import from jaclang.pycore.runtime { hookimpl, plugin_manager }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.server { JacAPIServer as JacServer }
import from .context { JScaleExecutionContext }
import from .serve { JacAPIServer }
import from .jserver.jfast_api { JFastApiServer }
import from .config_loader { get_scale_config }
import from .factories.deployment_factory { DeploymentTargetFactory }
import from .factories.registry_factory { ImageRegistryFactory }
import from .factories.utility_factory { UtilityFactory }
import from .abstractions.config.app_config { AppConfig }
import from .user_manager { JacScaleUserManager }
import from jaclang.runtimelib.server { UserManager }

"""Pre-hook for jac start command to handle --scale flag."""
def _scale_pre_hook(context: HookContext) -> None {
    scale = context.get_arg("scale", False);
    if scale {
        # Handle deployment instead of local server
        filename = context.get_arg("filename");
        build = context.get_arg("build", False);
        experimental = context.get_arg("experimental", False);
        target = context.get_arg("target", "kubernetes");
        registry = context.get_arg("registry", "dockerhub");
        if not os.path.exists(filename) {
            raise FileNotFoundError(f"File not found: '{filename}'") ;
        }
        code_folder = os.path.dirname(filename) or '.';
        dotenv_path = os.path.join(code_folder, '.env');
        load_dotenv(dotenv_path);
        code_folder = os.path.relpath(code_folder);
        code_folder = pathlib.Path(code_folder).as_posix();
        base_file_path = os.path.basename(filename);
        # Get configuration
        scale_config = get_scale_config();
        # Create logger
        logger = UtilityFactory.create_logger('standard');
        # Get target-specific config
        if target == 'kubernetes' {
            target_config = scale_config.get_kubernetes_config();
        } else {
            # For future targets, get from config
            target_config = scale_config.get_kubernetes_config();  # Default for now
        }
        # Create deployment target
        deployment_target = DeploymentTargetFactory.create(
            target, target_config, logger
        );
        # Handle image registry if build is requested
        if build {
            # Use target config for registry (it contains docker credentials)
            image_registry = ImageRegistryFactory.create(registry, target_config);
            deployment_target.image_registry = image_registry;
        }
        # Create app config
        app_config = AppConfig(
            code_folder=code_folder,
            file_name=base_file_path,
            build=build,
            experimental=experimental
        );
        if experimental {
            console.print(
                "Installing Jaseci packages from repository (experimental mode)..."
            );
        } else {
            console.print("Installing Jaseci packages from PyPI...");
        }
        # Deploy
        result = deployment_target.deploy(app_config);
        if not result.success {
            raise RuntimeError(result.message or "Deployment failed") ;
        }
        if result.service_url {
            console.print(
                f"Deployment complete! Service available at: {result.service_url}"
            );
        }
        # Cancel normal start execution since we handled it
        context.set_data("cancel_execution", True);
        context.set_data("cancel_return_code", 0);
    }
}

"""Jac CLI."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd -> None {
        """Jac Scale functionality.""";
        registry = get_registry();

        # Extend jac start with --scale and related flags
        registry.extend_command(
            "start",
            args=[
                Arg.create(
                    "scale",
                    typ=bool,
                    default=False,
                    help="Deploy to a target platform instead of running locally",
                    short=""  # Disable auto-generated -s (conflicts with --session)
                ),
                Arg.create(
                    "build",
                    typ=bool,
                    default=False,
                    help="Build and push Docker image (with --scale)",
                    short="b"
                ),
                Arg.create(
                    "experimental",
                    typ=bool,
                    default=False,
                    help="Use experimental mode (install from repo instead of PyPI)",
                    short="e"
                ),
                Arg.create(
                    "target",
                    typ=str,
                    default="kubernetes",
                    help="Deployment target (kubernetes, aws, gcp, etc.)",
                ),
                Arg.create(
                    "registry",
                    typ=str,
                    default="dockerhub",
                    help="Image registry (dockerhub, ecr, gcr, etc.)",
                ),

            ],
            pre_hook=_scale_pre_hook,
            source="jac-scale"
        );

        @registry.command(
            name="destroy",
            help="Remove deployment from target platform",
            args=[
                Arg.create(
                    "file_path", kind=ArgKind.POSITIONAL, help="Path to .jac file"
                ),
                Arg.create(
                    "target",
                    typ=str,
                    default="kubernetes",
                    help="Deployment target (kubernetes, aws, gcp, etc.)",
                ),

            ],
            examples=[("jac destroy app.jac", "Remove deployment for app"), ],
            group="deployment",
            priority=CommandPriority.PLUGIN,
            source="jac-scale"
        )
        def destroy(file_path: str, target: str = "kubernetes") -> int {
            if not os.path.exists(file_path) {
                raise FileNotFoundError(f"File not found: '{file_path}'") ;
            }
            code_folder = os.path.dirname(file_path) or '.';
            dotenv_path = os.path.join(code_folder, '.env');
            load_dotenv(dotenv_path);

            # Get configuration
            scale_config = get_scale_config();

            # Create logger
            logger = UtilityFactory.create_logger('standard');

            # Get target-specific config
            if target == 'kubernetes' {
                target_config = scale_config.get_kubernetes_config();
            } else {
                # For future targets, get from config
                target_config = scale_config.get_kubernetes_config();  # Default for now
            }

            # Create deployment target and destroy
            deployment_target = DeploymentTargetFactory.create(
                target, target_config, logger
            );
            app_name = os.getenv('APP_NAME') or target_config.get('app_name', 'jaseci');
            deployment_target.destroy(app_name);

            console.print(
                f"Successfully destroyed deployment '{app_name}' from {target}"
            );
            return 0;
        }
    }
}

"""Jac Scale Plugin Implementation."""
class JacScalePlugin {
    @hookimpl
    static def create_j_context(user_root: (str | None)) -> ExecutionContext {
        # Storage backend configured via environment (MONGODB_URI, etc.)
        ctx = JScaleExecutionContext();
        if user_root is not None {
            ctx.set_user_root(user_root);
        }
        return ctx;
    }

    """Create the API server instance."""
    @hookimpl
    static def create_server(
        jac_server: JacServer, host: str, port: int
    ) -> JFastApiServer {
        return JFastApiServer([]);
    }

    """Provide jac-scale's enhanced JacAPIServer class."""
    @hookimpl
    static def get_api_server_class -> type {
        return JacAPIServer;
    }

    """Provide jac-scale's UserManager."""
    @hookimpl
    static def get_user_manager(base_path: str) -> UserManager {
        return JacScaleUserManager(base_path=base_path);
    }
}

# Pluggy's varnames() puts parameters with defaults into kwargnames, not argnames.
# But _multicall only passes argnames to hook implementations.
# JacRuntimeInterfaceImpl strips defaults via generate_plugin_helpers, so we must too.
import inspect;
glob func = JacScalePlugin.create_j_context,
     sig = inspect.signature(func),
     sig_nodef = sig.replace(
         parameters=[
             p.replace(default=inspect.Parameter.empty)
             for p in sig.parameters.values()
         ]
     );

with entry {
    func.__signature__ = sig_nodef;
    plugin_manager.register(JacScalePlugin());
}
