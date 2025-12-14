"""Allow running jaclang as a module: python -m jaclang. (used for pre-commit hook)"""

from jaclang.cli.cli import start_cli

if __name__ == "__main__":
    start_cli()
