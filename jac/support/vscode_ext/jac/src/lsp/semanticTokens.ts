import * as vscode from 'vscode';

// Minimal semantic tokens provider.  The real implementation will ask the
// Jac language server for token data; for now it returns an empty result so the
// extension can register the capability without errors.

export const legend = new vscode.SemanticTokensLegend([], []);

export class JacSemanticTokensProvider implements vscode.DocumentSemanticTokensProvider {
    async provideDocumentSemanticTokens(): Promise<vscode.SemanticTokens> {
        const builder = new vscode.SemanticTokensBuilder(legend);
        return builder.build();
    }
}
