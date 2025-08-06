import * as vscode from 'vscode';
import { setupLspClient, client } from './lsp/client';
import { EnvManager } from './environment/manager';
import { registerAllCommands } from './commands';
import { setupVisualDebuggerWebview } from './webview/visualDebugger';
import { JacSemanticTokensProvider, legend as semanticLegend } from './lsp/semanticTokens';

export async function activate(context: vscode.ExtensionContext) {
    // Environment manager: handles env detection, selection, status bar
    const envManager = new EnvManager(context);
    await envManager.init();

    // LSP client: starts Jac language server using selected environment
    const lspClient = setupLspClient(envManager);
    context.subscriptions.push(lspClient);

    // Minimal semantic token provider.  Real semantic classifications will be
    // supplied by the language server once the type checker matures.
    context.subscriptions.push(
        vscode.languages.registerDocumentSemanticTokensProvider(
            { language: 'jac' },
            new JacSemanticTokensProvider(),
            semanticLegend,
        ),
    );

    // Register all extension commands (run, check, serve, env select, etc)
    registerAllCommands(context, envManager);

    // Visual debugger webview integration
    setupVisualDebuggerWebview(context, envManager);
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}

