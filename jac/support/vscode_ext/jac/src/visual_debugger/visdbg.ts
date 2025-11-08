import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export function makeWebView(): vscode.WebviewPanel  {
    let webviewPanel = vscode.window.createWebviewPanel(
         'jacvisWebview',
         'Jac Visual Debugger',
         vscode.ViewColumn.Two,
         {
             enableScripts: true,
         }
     );

     // TODO: This might not be the proper way to load the HTML content
     let dirSrc = path.join(path.dirname(path.dirname(__dirname)), "src");
     let pathHtml = path.join(dirSrc, "visual_debugger", "index.html");
     let htmlContent = fs.readFileSync(pathHtml, 'utf8');
     webviewPanel.webview.html = htmlContent;

     return webviewPanel;
 }


export async function getDebugGraphData(envManager?: any): Promise<JSON | null> {

    const debugSession = vscode.debug.activeDebugSession;
    if (!debugSession) {
        return null;
    }

    // Get the active thread ID
    const threads = await debugSession.customRequest('threads');
    if (!threads || !threads.threads || threads.threads.length === 0) {
        vscode.window.showErrorMessage('No active threads found.');
        return null;
    }

    // Use the first thread (usually the main thread)
    const threadId = threads.threads[0].id;

    // Get the stack trace for the thread
    const stackTrace = await debugSession.customRequest('stackTrace', { threadId });
    if (!stackTrace || !stackTrace.stackFrames || stackTrace.stackFrames.length === 0) {
        vscode.window.showErrorMessage('No stack frames found');
        return null;
    }

    // Use the top stack frame
    const frameId = stackTrace.stackFrames[0].id;

    // Use the selected jac environment path for visualization
    const jacPath = envManager ? envManager.getJacPath() : 'jac';
    
    // Evaluate to get the graph data using the correct jac path
    const response = await debugSession.customRequest('evaluate', {
        expression: "printgraph(format='json')",
        frameId,
        context: 'clipboard'
    });

    // Slicing 1, -1 cause it's a json string and contains quotation around it.
    try {
        return JSON.parse(response.result.slice(1, -1));
    } catch {
        vscode.window.showErrorMessage(`Error parsing: ${response.result}`);
    }

    return null;
}
