// mocks/vscode.ts
export const statusBarItem = {
  show: jest.fn(),
  hide: jest.fn(),
  text: '',
  tooltip: '',
  command: undefined,
};

export const vscodeMock = {
  window: {
    createStatusBarItem: () => statusBarItem,
    showWarningMessage: jest.fn(),
    showInformationMessage: jest.fn(),
    showErrorMessage: jest.fn(),
    showQuickPick: jest.fn(),
    showInputBox: jest.fn(),
    showOpenDialog: jest.fn(),
  },
  commands: {
    executeCommand: jest.fn(),
    registerCommand: jest.fn(),
  },
  env: {
    openExternal: jest.fn(),
  },
  Uri: {
    parse: jest.fn((str: string) => ({ fsPath: str, toString: () => str })),
    file: jest.fn((str: string) => ({ fsPath: str, toString: () => str })),
  },
  StatusBarAlignment: { Left: 1, Right: 2 },
  workspace: {
    workspaceFolders: [{ uri: { fsPath: '/mock/workspace' } }],
  },
};
