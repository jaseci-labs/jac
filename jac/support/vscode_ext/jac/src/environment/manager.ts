import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { findPythonEnvsWithJac, validateJacExecutable } from '../utils/envDetection';
import { getLspManager } from '../extension';

export class EnvManager {
    private context: vscode.ExtensionContext;
    private statusBar: vscode.StatusBarItem;
    private jacPath: string | undefined;

    constructor(context: vscode.ExtensionContext) {
        this.context = context;
        this.statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
        this.statusBar.command = 'jaclang-extension.selectEnv';
        context.subscriptions.push(this.statusBar);
    }


    async init() {
        // TODO: workspaceState
        this.jacPath = this.context.globalState.get<string>('jacEnvPath');
        
        // Always show status bar immediately, even before environment detection
        this.updateStatusBar();
        
        // Validate existing path if present
        if (this.jacPath && !(await validateJacExecutable(this.jacPath))) {
            vscode.window.showWarningMessage(
                `The previously selected Jac environment is no longer valid: ${this.jacPath}`,
                "Select New Environment"
            ).then(action => {
                if (action === "Select New Environment") {
                    this.promptEnvironmentSelection();
                }
            });
            this.jacPath = undefined;
            await this.context.globalState.update('jacEnvPath', undefined);
            this.updateStatusBar(); // Update after clearing invalid path
        }
        
        if (!this.jacPath) {
            await this.promptEnvironmentSelection();
        }
        
        // Final status bar update to ensure it's always shown
        this.updateStatusBar();
    }

    getJacPath(): string {
        if (this.jacPath) return this.jacPath;
        // Fallback: try to find jac in PATH
        return process.platform === 'win32' ? 'jac.exe' : 'jac';
    }

    async promptEnvironmentSelection() {
        try {
            const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || process.cwd();
            
            // Instant environment discovery - no progress dialogs needed!
            const envs = await findPythonEnvsWithJac(workspaceRoot);

            if (envs.length === 0) {
                // Always update status bar to show "No Env" even if user dismisses popup
                this.updateStatusBar();
                
                const action = await vscode.window.showWarningMessage(
                    "No Jac environments found. Install Jac to enable syntax highlighting, IntelliSense, and debugging!",
                    "Install Jac Now",
                    "Enter Jac Path Manually",
                    "Cancel"
                );
                
                if (action === "Install Jac Now") {
                    vscode.env.openExternal(vscode.Uri.parse('https://www.jac-lang.org/learn/installation/'));
                } else if (action === "Enter Jac Path Manually") {
                    await this.handleManualPathEntry();
                }
                // Status bar already updated above, so it will show "No Env" regardless of user action
                return;
            }

            // Create quick pick items exactly like VS Code Python interpreter selector
            const quickPickItems = envs.map(env => {
                const isGlobal = env === 'jac' || env === 'jac.exe' || 
                               (process.env.PATH?.split(path.delimiter) || []).some(dir => 
                                   path.join(dir, path.basename(env)) === env);
                
                let displayName = '';
                
                if (isGlobal) {
                    displayName = 'Jac';
                } else {
                    // Check if it's in a conda environment
                    if (env.includes('conda') || env.includes('miniconda') || env.includes('anaconda')) {
                        const envMatch = env.match(/envs[\/\\]([^\/\\]+)/);
                        displayName = envMatch ? `Jac (${envMatch[1]})` : 'Jac';
                    } 
                    // All other environments (venv, local, etc.)
                    else {
                        const venvMatch = env.match(/([^\/\\]*(?:\.?venv|virtualenv)[^\/\\]*)/);
                        if (venvMatch) {
                            displayName = `Jac (${venvMatch[1]})`;
                        } else {
                            // For Windows: go up from Scripts folder to get environment name
                            // For Unix: use the bin's parent directory name
                            const dirPath = path.dirname(env);
                            const parentDirName = path.basename(dirPath);
                            
                            if (parentDirName === 'Scripts' || parentDirName === 'bin') {
                                // Go up one more level to get the actual environment name
                                const envDirName = path.basename(path.dirname(dirPath));
                                displayName = `Jac (${envDirName})`;
                            } else {
                                displayName = `Jac (${parentDirName})`;
                            }
                        }
                    }
                }
                
                return {
                    label: displayName,
                    description: this.formatPathForDisplay(env),
                    env: env
                };
            });

            // Add special options at the top
            quickPickItems.unshift(
                {
                    label: "$(add) Enter interpreter path...",
                    description: "Manually specify the path to a Jac executable",
                    env: "manual"
                },
                {
                    label: "$(folder-opened) Find...",
                    description: "Browse for Jac executable using file picker",
                    env: "browse"
                }
            );

            const choice = await vscode.window.showQuickPick(quickPickItems, {
                placeHolder: `Select Jac environment (${envs.length} found)`,
                matchOnDescription: true,
                matchOnDetail: true,
                ignoreFocusOut: true
            });

            if (choice) {
                if (choice.env === "manual") {
                    await this.handleManualPathEntry();
                    return;
                } else if (choice.env === "browse") {
                    await this.handleFileBrowser();
                    return;
                }

                this.jacPath = choice.env;
                await this.context.globalState.update('jacEnvPath', choice.env);
                this.updateStatusBar();
                
                // Show success message with path details
                const displayPath = this.formatPathForDisplay(choice.env);
                vscode.window.showInformationMessage(
                    `Selected Jac environment: ${choice.label}`,
                    { detail: `Path: ${displayPath}` }
                );
                
                // Restart language server to use new environment
                await this.restartLanguageServer();
            } else {
                // User cancelled the quick pick - still update status bar
                this.updateStatusBar();
            }
        } catch (error: any) {
            // Always update status bar even when there's an error
            this.updateStatusBar();
            vscode.window.showErrorMessage(`Error finding Jac environments: ${error.message || error}`);
        }
    }


    /**
     * Handles manual path entry for Jac executable
     */
    private async handleManualPathEntry() {
        const manualPath = await vscode.window.showInputBox({
            prompt: "Enter the path to the Jac executable",
            placeHolder: "/path/to/jac or C:\\path\\to\\jac.exe",
            validateInput: (value) => {
                if (!value || value.trim().length === 0) {
                    return "Path cannot be empty";
                }
                // Basic validation - check if it looks like a valid path
                if (!path.isAbsolute(value) && !value.startsWith('~')) {
                    return "Please enter an absolute path";
                }
                return null;
            }
        });

        if (manualPath) {
            const normalizedPath = manualPath.startsWith('~') 
                ? path.join(process.env.HOME || process.env.USERPROFILE || '', manualPath.slice(1))
                : manualPath;

            // Validate the entered path
            if (await validateJacExecutable(normalizedPath)) {
                this.jacPath = normalizedPath;
                await this.context.globalState.update('jacEnvPath', normalizedPath);
                this.updateStatusBar();
                
                vscode.window.showInformationMessage(
                    `Jac environment set to: ${this.formatPathForDisplay(normalizedPath)}`
                );
                
                await this.restartLanguageServer();
            } else {
                const retry = await vscode.window.showErrorMessage(
                    `Invalid Jac executable: ${normalizedPath}`,
                    "Retry",
                    "Browse for File"
                );
                
                if (retry === "Retry") {
                    await this.handleManualPathEntry();
                } else if (retry === "Browse for File") {
                    await this.handleFileBrowser();
                }
            }
        }
    }

    /**
     * Handles file browser for selecting Jac executable
     */
    private async handleFileBrowser() {
        const fileUri = await vscode.window.showOpenDialog({
            canSelectFiles: true,
            canSelectFolders: false,
            canSelectMany: false,
            openLabel: "Select Jac Executable",
            filters: process.platform === 'win32' ? {
                'Executable Files': ['exe'],
                'All Files': ['*']
            } : {
                'All Files': ['*']
            },
            defaultUri: vscode.Uri.file(process.env.HOME || process.env.USERPROFILE || '/'),
            title: "Select Jac Executable"
        });

        if (fileUri && fileUri.length > 0) {
            const selectedPath = fileUri[0].fsPath;
            
            // Validate the selected file
            if (await validateJacExecutable(selectedPath)) {
                this.jacPath = selectedPath;
                await this.context.globalState.update('jacEnvPath', selectedPath);
                this.updateStatusBar();
                
                vscode.window.showInformationMessage(
                    `Jac environment set to: ${this.formatPathForDisplay(selectedPath)}`
                );
                
                await this.restartLanguageServer();
            } else {
                const retry = await vscode.window.showErrorMessage(
                    `The selected file is not a valid Jac executable: ${selectedPath}`,
                    "Try Again",
                    "Enter Path Manually"
                );
                
                if (retry === "Try Again") {
                    await this.handleFileBrowser();
                } else if (retry === "Enter Path Manually") {
                    await this.handleManualPathEntry();
                }
            }
        }
    }


    /**
     * Formats a file path for display in the quick pick, similar to VS Code Python extension
     */
    private formatPathForDisplay(envPath: string): string {
        const homeDir = process.env.HOME || process.env.USERPROFILE || '';
        
        // Replace home directory with ~
        if (homeDir && envPath.startsWith(homeDir)) {
            return envPath.replace(homeDir, '~');
        }
        
        // For very long paths, show just the relevant parts
        const pathParts = envPath.split(path.sep);
        if (pathParts.length > 6) {
            const start = pathParts.slice(0, 2).join(path.sep);
            const end = pathParts.slice(-3).join(path.sep);
            return `${start}${path.sep}...${path.sep}${end}`;
        }
        
        return envPath;
    }

    updateStatusBar() {
        if (this.jacPath) {
            const isGlobal = this.jacPath === 'jac' || this.jacPath === 'jac.exe' || 
                           (process.env.PATH?.split(path.delimiter) || []).some(dir => 
                               path.join(dir, path.basename(this.jacPath!)) === this.jacPath);
            
            const label = isGlobal ? 'Jac (Global)' : 'Jac';
            this.statusBar.text = `$(check) ${label}`;
            this.statusBar.tooltip = `Current: ${this.jacPath}${isGlobal ? ' (Global)' : ''}\nClick to change`;
        } else {
            this.statusBar.text = '$(warning) Jac: No Env';
            this.statusBar.tooltip = 'No Jac environment selected - Click to select';
        }
        this.statusBar.show();
    }

    private async restartLanguageServer(): Promise<void> {
        const lspManager = getLspManager();
        if (lspManager) {
            try {
                vscode.window.showInformationMessage('Restarting Jac Language Server to apply environment changes...');
                await lspManager.restart();
            } catch (error: any) {
                vscode.window.showErrorMessage(`Failed to restart language server: ${error.message || error}`);
                // Fallback to window reload if restart fails
                vscode.window.showWarningMessage('Falling back to window reload...');
                vscode.commands.executeCommand("workbench.action.reloadWindow");
            }
        } else {
            // Fallback to window reload if no LSP manager is available
            vscode.window.showInformationMessage('Reloading window to apply environment changes...');
            vscode.commands.executeCommand("workbench.action.reloadWindow");
        }
    }
}
