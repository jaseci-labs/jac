import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { runJacCommandForCurrentFile } from '../utils';
import { COMMANDS } from '../constants';

export function registerAllCommands(context: vscode.ExtensionContext, envManager: any) {
    context.subscriptions.push(
        vscode.commands.registerCommand(COMMANDS.SELECT_ENV, () => {
            envManager.promptEnvironmentSelection();
        })
    );
    context.subscriptions.push(
        vscode.commands.registerCommand(COMMANDS.REFRESH_ENV, () => {
            envManager.refreshEnvironments();
        })
    );
    context.subscriptions.push(
        vscode.commands.registerCommand(COMMANDS.RUN_FILE, () => {
            runJacCommandForCurrentFile('run', envManager);
        })
    );
    context.subscriptions.push(
        vscode.commands.registerCommand(COMMANDS.CHECK_FILE, () => {
            runJacCommandForCurrentFile('check', envManager);
        })
    );
    context.subscriptions.push(
        vscode.commands.registerCommand(COMMANDS.SERVE_FILE, () => {
            runJacCommandForCurrentFile('serve', envManager);
        })
    );
    context.subscriptions.push(
        vscode.commands.registerCommand('extension.jaclang-extension.getJacPath', config => {
            // Use envManager to get the selected jac path
            return envManager.getJacPath();
        })
    );
    context.subscriptions.push(
        vscode.commands.registerCommand('extension.jaclang-extension.getPythonPath', () => {
            // Use the new method from your EnvManager
            return envManager.getPythonPath();
        })
    );
}
