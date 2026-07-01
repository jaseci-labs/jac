import platform;
import from jaclang.cli.console { console }
glob JAC_LOGO = '   _\n  (_) __ _  ___\n  | |/ _` |/ __|\n  | | (_| | (__\n _/ |\\__,_|\\___|\n|__/',
     JAC_DOCS_URL = 'https://docs.jaseci.org',
     JAC_DISCORD_URL = 'https://discord.gg/6j3QNdtcN6',
     JAC_GITHUB_URL = 'https://github.com/Jaseci-Labs/jaseci',
     JAC_ISSUES_URL = 'https://github.com/Jaseci-Labs/jaseci/issues';

def print_logo(version: str, platform_short: str | None = None) {
    logo_lines = JAC_LOGO.split('\n');
    console.print(logo_lines[0], style='bold cyan');
    console.print((logo_lines[1] + '     Jac Language'), style='bold cyan');
    console.print(logo_lines[2], style='bold cyan');
    console.print((logo_lines[3] + f"     Version:  {version}"), style='cyan');
    console.print(logo_lines[4], style='cyan');
    last = logo_lines[5];
    if platform_short {
        last += f"                Platform: {platform_short}";
    }
    console.print(last, style='cyan');
}

def print_version_banner(version: str) {
    platform_info = platform.platform();
    if (platform.system() == 'Linux') {
        platform_short = f"Linux {platform.machine()}";
    } elif (platform.system() == 'Darwin') {
        platform_short = f"macOS {platform.machine()}";
    } elif (platform.system() == 'Windows') {
        platform_short = f"Windows {platform.machine()}";
    } else {
        platform_short = platform_info;
    }
    print_logo(version, platform_short);
    console.print(f'\n📚 Documentation: {JAC_DOCS_URL}');
    console.print(f'💬 Community:     {JAC_DISCORD_URL}');
    console.print(f'🐛 Issues:        {JAC_ISSUES_URL}');

    try {
        import from jaclang.jac0core.runtime { plugin_manager }
        seen: dict[str, str] = {};
        for (plugin, dist_facade) in plugin_manager.list_plugin_distinfo() {
            name = dist_facade.project_name;
            ver = dist_facade.version;
            if name not in seen {
                seen[name] = ver;
            }
        }
        if seen {
            console.print('\n🔌 Plugins Detected:');
            for name in sorted(seen.keys()) {
                console.print(f'   {name}=={seen[name]}');
            }
        }
    } except Exception { }
    console.print();
}
