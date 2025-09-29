/**
 * Mock VSCode API for testing
 */

// Mock status bar item
export const mockStatusBarItem = {
  text: '',
  tooltip: '',
  command: '',
  show: jest.fn(),
  hide: jest.fn(),
  dispose: jest.fn()
};

// Mock global state
export const mockGlobalState = {
  get: jest.fn(),
  update: jest.fn()
};

// Mock context
export const mockContext = {
  globalState: mockGlobalState,
  subscriptions: []
};

// Mock cancellation token
const mockCancellationToken = {
  isCancellationRequested: false,
  onCancellationRequested: jest.fn()
};

// Mock cancellation token source
export const mockCancellationTokenSource = {
  token: mockCancellationToken,
  cancel: jest.fn(),
  dispose: jest.fn()
};

// Mock window API
export const window = {
  createStatusBarItem: jest.fn(() => mockStatusBarItem),
  showQuickPick: jest.fn(),
  showInputBox: jest.fn(),
  showOpenDialog: jest.fn(),
  showInformationMessage: jest.fn(),
  showWarningMessage: jest.fn(),
  showErrorMessage: jest.fn(),
  withProgress: jest.fn()
};

// Mock commands API
export const commands = {
  executeCommand: jest.fn()
};

// Mock env API
export const env = {
  openExternal: jest.fn()
};

// Mock URI API
export const Uri = {
  parse: jest.fn(),
  file: jest.fn()
};

// Mock workspace API
export const workspace = {
  workspaceFolders: undefined
};

// Mock enums
export const StatusBarAlignment = {
  Left: 1,
  Right: 2
};

export const ProgressLocation = {
  Notification: 15,
  Window: 10,
  SourceControl: 1
};

// Mock CancellationTokenSource constructor
export const CancellationTokenSource = jest.fn(() => ({
  token: {
    isCancellationRequested: false,
    onCancellationRequested: jest.fn()
  },
  cancel: jest.fn(),
  dispose: jest.fn()
}));

// Export all mocks as default
export default {
  window,
  commands,
  env,
  Uri,
  workspace,
  StatusBarAlignment,
  ProgressLocation,
  CancellationTokenSource
};