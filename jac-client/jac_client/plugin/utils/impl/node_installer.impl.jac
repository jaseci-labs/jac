"""Implementation of Node.js installer methods."""

"""Check if Node.js is installed and accessible."""
impl NodeInstaller.is_node_installed -> bool {
    try {
        result = subprocess.run(
            ['node', '--version'], capture_output=True, text=True, timeout=5
        );
        return result.returncode == 0;
    } except (FileNotFoundError, subprocess.TimeoutExpired) {
        return False;
    }
}

"""Check if npm is installed and accessible."""
impl NodeInstaller.is_npm_installed -> bool {
    try {
        result = subprocess.run(
            ['npm', '--version'], capture_output=True, text=True, timeout=5
        );
        return result.returncode == 0;
    } except (FileNotFoundError, subprocess.TimeoutExpired) {
        return False;
    }
}

"""Check if NVM is installed."""
impl NodeInstaller.is_nvm_installed -> bool {
    nvm_dir = Path.home() / '.nvm';
    return nvm_dir.exists() and (nvm_dir / 'nvm.sh').exists();
}

"""Get the currently installed Node.js version."""
impl NodeInstaller.get_node_version -> (str | None) {
    try {
        result = subprocess.run(
            ['node', '--version'], capture_output=True, text=True, timeout=5
        );
        if result.returncode == 0 {
            return result.stdout.strip();
        }
    } except (FileNotFoundError, subprocess.TimeoutExpired) { }
    return None;
}

"""Install NVM (Node Version Manager)."""
impl NodeInstaller.install_nvm -> tuple[bool, str] {
    system = platform.system();
    if system == 'Windows' {
        return (
            False,
            'Windows detected. Please install Node.js manually:\n' + '  1. Download from: https://nodejs.org/\n' + '  2. Or use nvm-windows: https://github.com/coreybutler/nvm-windows\n' + '  After installation, run "jac add --cl" again.'
        );
    }
    print('Installing NVM (Node Version Manager)...');
    try {
        # Download and run NVM installation script
        install_script = subprocess.run(
            ['curl', '-o-', NodeInstaller.NVM_INSTALL_URL],
            capture_output=True,
            text=True,
            timeout=30
        );

        if install_script.returncode != 0 {
            return (
                False,
                f'Failed to download NVM installer: {install_script.stderr}'
            );
        }

        # Execute the installation script
        result = subprocess.run(
            ['bash', '-c', install_script.stdout],
            capture_output=True,
            text=True,
            timeout=60
        );

        if result.returncode != 0 {
            return (False, f'NVM installation failed: {result.stderr}');
        }

        print('NVM installed successfully!');
        return (True, 'NVM installed successfully');
    } except subprocess.TimeoutExpired {
        return (
            False,
            'NVM installation timed out. Please check your internet connection.'
        );
    } except FileNotFoundError as e {
        if 'curl' in str(e) {
            return (
                False,
                'curl command not found. Please install curl first:\n' + '  Ubuntu/Debian: sudo apt-get install curl\n' + '  macOS: curl is pre-installed\n' + '  Fedora/RHEL: sudo dnf install curl'
            );
        }
        return (False, f'Required command not found: {e}');
    } except Exception as e {
        return (False, f'Unexpected error during NVM installation: {e}');
    }
}

"""Install Node.js using NVM."""
impl NodeInstaller.install_node_via_nvm(version: str = "20") -> tuple[bool, str] {
    print(f'Installing Node.js v{version} via NVM...');
    nvm_dir = Path.home() / '.nvm';
    nvm_script = nvm_dir / 'nvm.sh';
    if not nvm_script.exists() {
        return (False, 'NVM is not installed or nvm.sh not found');
    }
    try {
        # Source NVM and install Node.js
        command = (
            'export NVM_DIR="$HOME/.nvm"\n' + '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' + f'nvm install {version}\n' + f'nvm use {version}\n' + f'nvm alias default {version}\n'
        );

        result = subprocess.run(
            ['bash', '-c', command], capture_output=True, text=True, timeout=300
        );

        if result.returncode != 0 {
            return (False, f'Node.js installation failed: {result.stderr}');
        }

        print(f'Node.js v{version} installed successfully!');
        return (True, f'Node.js v{version} installed successfully');
    } except subprocess.TimeoutExpired {
        return (False, 'Node.js installation timed out. Please try again.');
    } except Exception as e {
        return (False, f'Unexpected error during Node.js installation: {e}');
    }
}

"""Ensure Node.js is installed, installing automatically if needed.

Returns tuple of (success: bool, message: str, was_just_installed: bool)
"""
impl NodeInstaller.ensure_node_installed(
    interactive: bool = True
) -> tuple[bool, str, bool] {
    # Common fallback message for manual installation
    manual_install_msg = (
        'Please install Node.js manually:\n' + '  • Download from: https://nodejs.org/\n' + '  • Or install NVM: https://github.com/nvm-sh/nvm\n' + '  After installation, run "jac add --cl" again.'
    );
    # Check if Node.js is already available
    if NodeInstaller.is_node_installed() and NodeInstaller.is_npm_installed() {
        version = NodeInstaller.get_node_version();
        return (True, f'Node.js {version} is already installed', False);
    }
    print('\nNode.js is not installed or not found in PATH.');
    # Check for interactive mode
    if interactive {
        print(
            '\nJac client requires Node.js to build and run client-side applications.'
        );
        print(
            f'Would you like to automatically install Node.js v{NodeInstaller.DEFAULT_NODE_VERSION} using NVM?'
        );
        response = input('Install Node.js? [Y/n]: ').strip().lower();
        if response and response not in ('y', 'yes') {
            return (
                False,
                f'Node.js installation cancelled. {manual_install_msg}',
                False
            );
        }
    }
    # Wrap entire installation process in error handling
    try {
        # Check if NVM is installed
        if not NodeInstaller.is_nvm_installed() {
            success_nvm = NodeInstaller.install_nvm();
            if not success_nvm[0] {
                return (
                    False,
                    f'Unable to automatically install Node.js.\n\nError: {success_nvm[
                        1
                    ]}\n\n{manual_install_msg}',
                    False
                );
            }
        }

        # Install Node.js via NVM
        success_node = NodeInstaller.install_node_via_nvm();
        if not success_node[0] {
            return (
                False,
                f'Unable to automatically install Node.js.\n\nError: {success_node[1]}\n\n{manual_install_msg}',
                False
            );
        }

        # Node.js is now available via NVM sourcing in subprocesses
        print('\n' + '=' * 70);
        print('Node.js has been installed successfully!');
        print('Continuing with package installation...');
        print('=' * 70 + '\n');

        return (
            True,
            f'Node.js {NodeInstaller.DEFAULT_NODE_VERSION} installed successfully',
            True
        );
    } except Exception as e {
        # Catch any unexpected errors during installation
        return (
            False,
            f'Unable to automatically install Node.js.\n\nUnexpected error: {str(e)}\n\n{manual_install_msg}',
            False
        );
    }
}

"""Run npm command with NVM environment properly sourced.

This method automatically sources NVM in a subprocess, so npm commands work
immediately after NVM installation without requiring the user to reload their shell.
"""
impl NodeInstaller.run_npm_with_nvm(
    args: list, cwd: Path, timeout: int = 300
) -> object {
    # First, try running npm directly (in case it's already in PATH)
    try {
        return subprocess.run(
            ['npm'] + args,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=True
        );
    } except FileNotFoundError { }
    # If npm is not in PATH, source NVM and run npm in a subprocess
    # This allows npm to work immediately after installation without shell reload
    args_str = ' '.join(args);
    command = (
        'export NVM_DIR="$HOME/.nvm"\n' + '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' + f'npm {args_str}\n'
    );
    return subprocess.run(
        ['bash', '-c', command],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=True
    );
}
