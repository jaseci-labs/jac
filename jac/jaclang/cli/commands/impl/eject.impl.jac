import from pathlib { Path }
import from jaclang.cli.console { console }

impl eject(
    source: str = '.',
    output: str = '',
    force: bool = False,
    app: str = '',
    entry_override: str = ''
) -> int {
    import from jaclang.project.config { JacConfig, set_config }
    import from jaclang.dist.source.project { export_project }
    directory = Path(source).resolve();
    try {
        config = JacConfig.load(directory / 'jac.toml');
        set_config(config);
        target = Path(output) if output else directory / 'dist' / 'source';
        result = export_project(config, app, target, entry_override, force);
    } except (OSError, ValueError, RuntimeError) as error {
        console.error(str(error));
        return 1;
    }
    console.success(f'Exported source project: {result}');
    return 0;
}
