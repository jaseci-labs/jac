"""Branding and banner utilities for Jac CLI.

This module contains ASCII art, banners, and branded output for the Jac CLI.
"""
import platform;
import sys;
import from jaclang.cli.console { console }
glob JAC_LOGO = '   _\n  (_) __ _  ___\n  | |/ _` |/ __|\n  | | (_| | (__\n _/ |\\__,_|\\___|\n|__/',
     JAC_DOCS_URL = 'https://docs.jaseci.org',
     JAC_DISCORD_URL = 'https://discord.gg/6j3QNdtcN6',
     JAC_GITHUB_URL = 'https://github.com/Jaseci-Labs/jaseci',
     JAC_ISSUES_URL = 'https://github.com/Jaseci-Labs/jaseci/issues';

"""Print the full version banner with logo and system info.

    Args:
        version: Jac version string
    """
def print_version_banner(version: str) -> None {
    python_version = f"Python {sys.version.split()[0]}";
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
    logo_lines = JAC_LOGO.split('\n');
    console.print(logo_lines[0], style='bold cyan');
    console.print((logo_lines[1] + '     Jac Language'), style='bold cyan');
    console.print(logo_lines[2], style='bold cyan');
    console.print((logo_lines[3] + f"     Version:  {version}"), style='cyan');
    console.print((logo_lines[4] + f"    {python_version}"), style='cyan');
    console.print(
        (logo_lines[5] + f"                Platform: {platform_short}"), style='cyan'
    );
    console.print(f'\n📚 Documentation: [url]{JAC_DOCS_URL}[/url]');
    console.print(f'💬 Community:     [url]{JAC_DISCORD_URL}[/url]');
    console.print(f'🐛 Issues:        [url]{JAC_ISSUES_URL}[/url]');
    console.print();
}

"""Print header for server startup.

    Args:
        mode: Server mode (development, production, etc.)
    """
def print_startup_header(mode: str = 'development') -> None {
    console.print('\n  JAC DEV SERVER', style='bold cyan');
    console.print();
}

"""Print a celebration message.

    Args:
        message: Message to display
    """
def print_celebration(message: str = 'Happy coding!') -> None {
    console.print(f"🚀 {message}", style='bold green');
}
