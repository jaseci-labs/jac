import * as vscode from 'vscode';
import { makeWebView, getDebugGraphData } from '../visual_debugger/visdbg';

export function setupVisualDebuggerWebview(context: vscode.ExtensionContext, envManager: any) {
    let webviewPanel: vscode.WebviewPanel | undefined;
    let graphData: JSON = JSON.parse('{}');

    context.subscriptions.push(
        vscode.commands.registerCommand('jac.visualize', async () => {
            if (webviewPanel) {
                webviewPanel.reveal();
            } else {
                webviewPanel = makeWebView();
                webviewPanel.onDidDispose(() => { webviewPanel = undefined; });
            }
        })
    );

    vscode.debug.onDidStartDebugSession(async () => {
        if (webviewPanel) {
            graphData = await getDebugGraphData(envManager);
            if (graphData != null) {
                webviewPanel.webview.postMessage({
                    "command": "init",
                    "data": graphData,
                });
            }
        }
    });

    vscode.debug.onDidChangeActiveStackItem(async () => {
        if (webviewPanel) {
            graphData = await getDebugGraphData(envManager);
            if (graphData != null) {
                webviewPanel.webview.postMessage({
                    "command": "update",
                    "data": graphData,
                });
            }
        }
    });

    vscode.debug.onDidTerminateDebugSession(() => {
        if (webviewPanel) {
            webviewPanel.webview.postMessage({
                "command": "clear",
            });
        }
    });
}
