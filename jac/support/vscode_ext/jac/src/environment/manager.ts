import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { findPythonEnvsWithJac, clearEnvironmentCache, isCacheValid } from '../utils/envDetection';

export class EnvManager {
    private context: vscode.ExtensionContext;
    private statusBar: vscode.StatusBarItem;
    private jacPath: string | undefined;
    private isScanning: boolean = false;

    constructor(context: vscode.ExtensionContext) {
        this.context = context;
        this.statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
        this.statusBar.command = 'jaclang-extension.selectEnv';
        context.subscriptions.push(this.statusBar);
    }

    async init() {
        this.jacPath = this.context.globalState.get<string>('jacEnvPath');
        if (!this.jacPath) {
            await this.promptEnvironmentSelection();
        }
        this.updateStatusBar();
    }

    getJacPath(): string {
        if (this.jacPath) return this.jacPath;
        // Fallback: try to find jac in PATH
        return process.platform === 'win32' ? 'jac.exe' : 'jac';
    }

    async promptEnvironmentSelection(forceRefresh: boolean = false) {
        if (this.isScanning) {
            vscode.window.showInformationMessage('Environment scan already in progress...');
            return;
        }

        this.isScanning = true;
        this.updateStatusBar();

        try {
            const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || process.cwd();
            
            // Show progress for environment detection
            const envs = await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: "Discovering Jac environments",
                cancellable: false
            }, async (progress) => {
                if (forceRefresh) {
                    clearEnvironmentCache();
                    progress.report({ message: "Clearing cache and scanning..." });
                } else if (isCacheValid()) {
                    progress.report({ message: "Using cached results..." });
                } else {
                    progress.report({ message: "Scanning for environments..." });
                }
                
                return await findPythonEnvsWithJac(workspaceRoot, !forceRefresh);
            });

            if (envs.length === 0) {
                const action = await vscode.window.showWarningMessage(
                    "No environments with 'jac' executable found.",
                    "Refresh Scan",
                    "Cancel"
                );
                if (action === "Refresh Scan") {
                    await this.promptEnvironmentSelection(true);
                }
                return;
            }

            // Create quick pick items with additional info
            const quickPickItems = envs.map(env => ({
                label: path.basename(env),
                description: path.dirname(env),
                detail: env.startsWith('wsl:') ? 'WSL Environment' : 'Local Environment',
                env: env
            }));

            // Add refresh option at the top
            quickPickItems.unshift({
                label: "$(refresh) Refresh Environment List",
                description: "Rescan for environments",
                detail: "Clear cache and search again",
                env: "refresh"
            });

            const choice = await vscode.window.showQuickPick(quickPickItems, {
                placeHolder: `Select environment (${isCacheValid() ? 'cached' : 'fresh'} results)`,
                matchOnDescription: true,
                matchOnDetail: true
            });

            if (choice) {
                if (choice.env === "refresh") {
                    await this.promptEnvironmentSelection(true);
                    return;
                }

                this.jacPath = choice.env;
                await this.context.globalState.update('jacEnvPath', choice.env);
                this.updateStatusBar();
                vscode.window.showInformationMessage(`Jac environment set to: ${choice.label}`);
                vscode.commands.executeCommand("workbench.action.reloadWindow");
            }
        } catch (error) {
            vscode.window.showErrorMessage(`Error scanning for environments: ${error}`);
        } finally {
            this.isScanning = false;
            this.updateStatusBar();
        }
    }

    async refreshEnvironments() {
        await this.promptEnvironmentSelection(true);
    }

    getPythonPath(): string {
        const jacPath = this.getJacPath(); // Use the existing method to get jac's path

        // If jacPath is just 'jac', then python is probably just 'python' in the PATH
        if (jacPath === 'jac' || jacPath === 'jac.exe') {
            return process.platform === 'win32' ? 'python.exe' : 'python';
        }

        // Otherwise, construct the path: C:\path\to\env\Scripts\python.exe
        const dir = path.dirname(jacPath);
        const pythonExe = process.platform === 'win32' ? 'python.exe' : 'python';
        return path.join(dir, pythonExe);
    }

    updateStatusBar() {
        if (this.isScanning) {
            this.statusBar.text = "$(sync~spin) Scanning Jac Envs...";
            this.statusBar.tooltip = "Scanning for Jac environments";
        } else {
            const label = this.jacPath ? path.basename(this.jacPath) : 'No Env';
            const cacheStatus = isCacheValid() ? '$(check)' : '$(refresh)';
            this.statusBar.text = `${cacheStatus} Jac: ${label}`;
            this.statusBar.tooltip = this.jacPath ? 
                `Current: ${this.jacPath}\nClick to change or refresh` : 
                'No Jac environment selected - Click to select';
        }
        this.statusBar.show();
    }
}
