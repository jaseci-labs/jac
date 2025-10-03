import * as vscode from 'vscode';
import { EnvManager } from './environment/manager';
import { registerAllCommands } from './commands';
import { setupVisualDebuggerWebview } from './webview/visualDebugger';
import { LspManager } from './lsp/lsp_manager';

let lspManager: LspManager | undefined;

export function getLspManager(): LspManager | undefined {
    return lspManager;
}

export async function activate(context: vscode.ExtensionContext) {
    try {
        const envManager = new EnvManager(context);
        registerAllCommands(context, envManager);
        await envManager.init();

        setupVisualDebuggerWebview(context, envManager);

        lspManager = new LspManager(envManager);
        await lspManager.start();

        context.subscriptions.push({
            dispose: () => lspManager?.stop()
        });
    } catch (error) {
        vscode.window.showErrorMessage(`Failed to activate Jac extension: ${error}`);
        console.error('Extension activation error:', error);
    }
}

export function deactivate(): Thenable<void> | undefined {
    return lspManager?.stop();
}
