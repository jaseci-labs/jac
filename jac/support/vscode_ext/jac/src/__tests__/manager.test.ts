/**
 * Tests for environment/manager.ts - Environment Manager Class
 */

// Mock vscode module
jest.mock('vscode');

import { EnvManager } from '../environment/manager';
import * as vscode from 'vscode';
import * as envDetection from '../utils/envDetection';

// Mock environment detection utilities
jest.mock('../utils/envDetection');

const mockEnvDetection = jest.mocked(envDetection);
const mockVscode = jest.mocked(vscode);

describe('EnvManager', () => {
  let manager: EnvManager;
  let mockContext: any;
  let mockStatusBarItem: any;
  let originalPlatform: NodeJS.Platform;
  let originalEnv: NodeJS.ProcessEnv;

  beforeEach(() => {
    // Store original values
    originalPlatform = process.platform;
    originalEnv = { ...process.env };

    // Create mock status bar item
    mockStatusBarItem = {
      text: '',
      tooltip: '',
      command: '',
      show: jest.fn(),
      hide: jest.fn(),
      dispose: jest.fn()
    };

    // Create mock context
    mockContext = {
      globalState: {
        get: jest.fn(),
        update: jest.fn()
      },
      subscriptions: []
    };

    // Setup mocks
    mockVscode.window.createStatusBarItem.mockReturnValue(mockStatusBarItem);
    
    // Mock CancellationTokenSource
    mockVscode.CancellationTokenSource = jest.fn().mockImplementation(() => ({
      token: {
        isCancellationRequested: false,
        onCancellationRequested: jest.fn()
      },
      cancel: jest.fn(),
      dispose: jest.fn()
    }));
    
    // Reset mocks
    jest.clearAllMocks();
    
    // Create manager instance
    manager = new EnvManager(mockContext);
  });

  afterEach(() => {
    // Restore original values
    Object.defineProperty(process, 'platform', {
      value: originalPlatform,
      configurable: true
    });
    process.env = originalEnv;
  });

  describe('Initialization', () => {
    it('should create status bar item on construction', () => {
      expect(mockVscode.window.createStatusBarItem).toHaveBeenCalledWith(
        mockVscode.StatusBarAlignment.Left,
        100
      );
      expect(mockStatusBarItem.command).toBe('jaclang-extension.selectEnv');
    });

    it('should initialize with existing valid environment', async () => {
      // Mock existing environment path
      mockContext.globalState.get.mockReturnValue('/usr/local/bin/jac');
      mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

      await manager.init();

      expect(mockContext.globalState.get).toHaveBeenCalledWith('jacEnvPath');
      expect(mockEnvDetection.validateJacExecutable).toHaveBeenCalledWith('/usr/local/bin/jac');
    });

    it('should handle invalid existing environment', async () => {
      // Mock existing invalid environment path
      mockContext.globalState.get.mockReturnValue('/invalid/jac');
      mockEnvDetection.validateJacExecutable.mockResolvedValue(false);
      mockVscode.window.showWarningMessage.mockResolvedValue({ title: 'Select New Environment' } as any);
      
      // Mock environment discovery
      mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(['/usr/local/bin/jac']);
      mockVscode.window.showQuickPick.mockResolvedValue({
        label: 'Jac',
        description: '/usr/local/bin/jac',
        env: '/usr/local/bin/jac'
      } as any);

      await manager.init();

      expect(mockVscode.window.showWarningMessage).toHaveBeenCalledWith(
        expect.stringContaining('The previously selected Jac environment is no longer valid'),
        'Select New Environment'
      );
    });

    it('should prompt for environment selection when none exists', async () => {
      // Mock no existing environment
      mockContext.globalState.get.mockReturnValue(undefined);
      
      // Mock environment discovery
      mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(['/usr/local/bin/jac']);
      mockVscode.window.withProgress.mockImplementation(async (options, task) => {
        return await task({ report: jest.fn() }, { 
          isCancellationRequested: false,
          onCancellationRequested: jest.fn() 
        });
      });
      mockVscode.window.showQuickPick.mockResolvedValue({
        label: 'Jac',
        description: '/usr/local/bin/jac',
        env: '/usr/local/bin/jac'
      } as any);

      await manager.init();

      expect(mockEnvDetection.findPythonEnvsWithJac).toHaveBeenCalled();
    });
  });

  describe('Environment Selection', () => {
    describe('Linux Environment Display', () => {
      beforeEach(() => {
        Object.defineProperty(process, 'platform', {
          value: 'linux' as NodeJS.Platform,
          configurable: true
        });
        process.env.PATH = '/usr/local/bin:/usr/bin:/bin';
        process.env.HOME = '/home/testuser';
      });

      it('should display global jac environment correctly', async () => {
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(['/usr/local/bin/jac']);
        mockVscode.window.withProgress.mockImplementation(async (options, task) => {
          return await task({ report: jest.fn() }, { 
            isCancellationRequested: false,
            onCancellationRequested: jest.fn() 
          });
        });
        
        const mockShowQuickPick = mockVscode.window.showQuickPick.mockResolvedValue(undefined);

        await manager.promptEnvironmentSelection();

        expect(mockShowQuickPick).toHaveBeenCalledWith(
          expect.arrayContaining([
            expect.objectContaining({
              label: 'Jac',
              description: '/usr/local/bin/jac'
            })
          ]),
          expect.any(Object)
        );
      });

      it('should display venv environments with proper labels', async () => {
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([
          '/home/testuser/project/.venv/bin/jac',
          '/home/testuser/myproject/venv/bin/jac'
        ]);
        mockVscode.window.withProgress.mockImplementation(async (options, task) => {
          return await task({ report: jest.fn() }, { 
            isCancellationRequested: false,
            onCancellationRequested: jest.fn() 
          });
        });
        
        const mockShowQuickPick = mockVscode.window.showQuickPick.mockResolvedValue(undefined);

        await manager.promptEnvironmentSelection();

        expect(mockShowQuickPick).toHaveBeenCalledWith(
          expect.arrayContaining([
            expect.objectContaining({
              label: 'Jac (.venv)',
              description: expect.stringContaining('.venv/bin/jac')
            }),
            expect.objectContaining({
              label: 'Jac (venv)',
              description: expect.stringContaining('venv/bin/jac')
            })
          ]),
          expect.any(Object)
        );
      });

      it('should display conda environments with environment names', async () => {
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([
          '/opt/miniconda3/envs/jacenv/bin/jac',
          '/opt/miniconda3/envs/myproject/bin/jac'
        ]);
        mockVscode.window.withProgress.mockImplementation(async (options, task) => {
          return await task({ report: jest.fn() }, { 
            isCancellationRequested: false,
            onCancellationRequested: jest.fn() 
          });
        });
        
        const mockShowQuickPick = mockVscode.window.showQuickPick.mockResolvedValue(undefined);

        await manager.promptEnvironmentSelection();

        expect(mockShowQuickPick).toHaveBeenCalledWith(
          expect.arrayContaining([
            expect.objectContaining({
              label: 'Jac (jacenv)',
              description: expect.stringContaining('jacenv/bin/jac')
            }),
            expect.objectContaining({
              label: 'Jac (myproject)',
              description: expect.stringContaining('myproject/bin/jac')
            })
          ]),
          expect.any(Object)
        );
      });
    });

    describe('Windows Environment Display', () => {
      beforeEach(() => {
        Object.defineProperty(process, 'platform', {
          value: 'win32' as NodeJS.Platform,
          configurable: true
        });
        process.env.PATH = 'C:\\Windows\\System32;C:\\Python39\\Scripts';
        process.env.USERPROFILE = 'C:\\Users\\TestUser';
        delete process.env.HOME;
      });

      it('should display global jac environment correctly on Windows', async () => {
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(['C:\\Python39\\Scripts\\jac.exe']);
        mockVscode.window.withProgress.mockImplementation(async (options, task) => {
          return await task({ report: jest.fn() }, { 
            isCancellationRequested: false,
            onCancellationRequested: jest.fn() 
          });
        });
        
        const mockShowQuickPick = mockVscode.window.showQuickPick.mockResolvedValue(undefined);

        await manager.promptEnvironmentSelection();

        expect(mockShowQuickPick).toHaveBeenCalledWith(
          expect.arrayContaining([
            expect.objectContaining({
              label: expect.stringContaining('Jac'),
              description: 'C:\\Python39\\Scripts\\jac.exe'
            })
          ]),
          expect.any(Object)
        );
      });

      it('should display Windows venv environments correctly', async () => {
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([
          'C:\\Users\\TestUser\\project\\venv\\Scripts\\jac.exe',
          'C:\\Projects\\myapp\\.venv\\Scripts\\jac.exe'
        ]);
        mockVscode.window.withProgress.mockImplementation(async (options, task) => {
          return await task({ report: jest.fn() }, { 
            isCancellationRequested: false,
            onCancellationRequested: jest.fn() 
          });
        });
        
        const mockShowQuickPick = mockVscode.window.showQuickPick.mockResolvedValue(undefined);

        await manager.promptEnvironmentSelection();

        expect(mockShowQuickPick).toHaveBeenCalledWith(
          expect.arrayContaining([
            expect.objectContaining({
              label: 'Jac (venv)',
              description: expect.stringContaining('venv\\Scripts\\jac.exe')
            }),
            expect.objectContaining({
              label: 'Jac (.venv)',
              description: expect.stringContaining('.venv\\Scripts\\jac.exe')
            })
          ]),
          expect.any(Object)
        );
      });

      it('should display Windows conda environments correctly', async () => {
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([
          'C:\\Miniconda3\\envs\\jacenv\\Scripts\\jac.exe'
        ]);
        mockVscode.window.withProgress.mockImplementation(async (options, task) => {
          return await task({ report: jest.fn() }, { 
            isCancellationRequested: false,
            onCancellationRequested: jest.fn() 
          });
        });
        
        const mockShowQuickPick = mockVscode.window.showQuickPick.mockResolvedValue(undefined);

        await manager.promptEnvironmentSelection();

        expect(mockShowQuickPick).toHaveBeenCalledWith(
          expect.arrayContaining([
            expect.objectContaining({
              label: 'Jac (jacenv)',
              description: expect.stringContaining('jacenv\\Scripts\\jac.exe')
            })
          ]),
          expect.any(Object)
        );
      });
    });

    it('should handle no environments found', async () => {
      mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([]);
      mockVscode.window.withProgress.mockImplementation(async (options, task) => {
        return await task({ report: jest.fn() }, { 
          isCancellationRequested: false,
          onCancellationRequested: jest.fn() 
        });
      });
      
      mockVscode.window.showWarningMessage.mockResolvedValue({ title: 'Install Jac Now' } as any);

      await manager.promptEnvironmentSelection();

      expect(mockVscode.window.showWarningMessage).toHaveBeenCalledWith(
        expect.stringContaining('No Jac environments found'),
        'Install Jac Now',
        'Enter Jac Path Manually',
        'Cancel'
      );
      expect(mockVscode.env.openExternal).toHaveBeenCalledWith(
        expect.objectContaining({})
      );
    });

    it('should handle manual path entry', async () => {
      mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([]);
      mockVscode.window.withProgress.mockImplementation(async (options, task) => {
        return await task({ report: jest.fn() }, { 
          isCancellationRequested: false,
          onCancellationRequested: jest.fn() 
        });
      });
      
      mockVscode.window.showWarningMessage.mockResolvedValue({ title: 'Enter Jac Path Manually' } as any);
      mockVscode.window.showInputBox.mockResolvedValue('/custom/path/jac');
      mockEnvDetection.validateJacExecutable.mockResolvedValue(true);
      mockVscode.window.showInformationMessage.mockResolvedValue(undefined);

      await manager.promptEnvironmentSelection();

      expect(mockVscode.window.showInputBox).toHaveBeenCalledWith(
        expect.objectContaining({
          prompt: expect.stringContaining('Enter the path to the Jac executable')
        })
      );
      expect(mockEnvDetection.validateJacExecutable).toHaveBeenCalledWith('/custom/path/jac');
    });
  });

  describe('Status Bar Updates', () => {
    it('should show scanning status when scanning', () => {
      // Access private method for testing
      (manager as any).isScanning = true;
      manager.updateStatusBar();

      expect(mockStatusBarItem.text).toContain('Scanning Jac Envs');
      expect(mockStatusBarItem.tooltip).toContain('Scanning for Jac environments');
    });

    it('should show selected environment when available', () => {
      // Mock selected environment
      (manager as any).jacPath = '/usr/local/bin/jac';
      manager.updateStatusBar();

      expect(mockStatusBarItem.text).toContain('Jac');
      expect(mockStatusBarItem.tooltip).toContain('/usr/local/bin/jac');
      expect(mockStatusBarItem.show).toHaveBeenCalled();
    });

    it('should show warning when no environment selected', () => {
      // Mock no environment selected
      (manager as any).jacPath = undefined;
      manager.updateStatusBar();

      expect(mockStatusBarItem.text).toContain('No Env');
      expect(mockStatusBarItem.tooltip).toContain('No Jac environment selected');
    });

    it('should indicate global environment properly', () => {
      // Mock global environment
      (manager as any).jacPath = 'jac';
      process.env.PATH = '/usr/local/bin:/usr/bin';
      
      manager.updateStatusBar();

      expect(mockStatusBarItem.text).toContain('Jac (Global)');
      expect(mockStatusBarItem.tooltip).toContain('Global');
    });
  });

  describe('Environment Validation', () => {
    it('should validate current environment successfully', async () => {
      (manager as any).jacPath = '/usr/local/bin/jac';
      mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

      const result = await manager.validateCurrentEnvironment();

      expect(result).toBe(true);
      expect(mockEnvDetection.validateJacExecutable).toHaveBeenCalledWith('/usr/local/bin/jac');
    });

    it('should return false for invalid environment', async () => {
      (manager as any).jacPath = '/invalid/jac';
      mockEnvDetection.validateJacExecutable.mockResolvedValue(false);

      const result = await manager.validateCurrentEnvironment();

      expect(result).toBe(false);
    });

    it('should return false when no environment set', async () => {
      (manager as any).jacPath = undefined;

      const result = await manager.validateCurrentEnvironment();

      expect(result).toBe(false);
    });
  });

  describe('Python Path Derivation', () => {
    it('should derive python path from jac path on Linux', () => {
      (manager as any).jacPath = '/opt/miniconda3/envs/jacenv/bin/jac';
      
      const pythonPath = manager.getPythonPath();
      
      expect(pythonPath).toBe('/opt/miniconda3/envs/jacenv/bin/python');
    });

    it('should derive python path from jac path on Windows', () => {
      Object.defineProperty(process, 'platform', {
        value: 'win32' as NodeJS.Platform,
        configurable: true
      });
      
      // Mock Windows path functions
      const mockPath = require('path');
      mockPath.dirname = jest.fn().mockImplementation((p: string) => {
        const parts = p.split('\\');
        return parts.slice(0, -1).join('\\');
      });
      mockPath.join = jest.fn().mockImplementation((...args: string[]) => args.join('\\'));
      
      (manager as any).jacPath = 'C:\\Miniconda3\\envs\\jacenv\\Scripts\\jac.exe';
      
      const pythonPath = manager.getPythonPath();
      
      expect(pythonPath).toBe('C:\\Miniconda3\\envs\\jacenv\\Scripts\\python.exe');
    });

    it('should fall back to global python when jac is global', () => {
      (manager as any).jacPath = 'jac';
      
      const pythonPath = manager.getPythonPath();
      
      expect(pythonPath).toBe('python');
    });
  });

  describe('Error Handling', () => {
    it('should handle environment scan timeout', async () => {
      mockEnvDetection.findPythonEnvsWithJac.mockRejectedValue(new Error('Environment scan timeout'));
      mockVscode.window.withProgress.mockImplementation(async (options, task) => {
        throw new Error('Environment scan timeout');
      });
      
      mockVscode.window.showWarningMessage.mockResolvedValue({ title: 'Try Again' } as any);

      await manager.promptEnvironmentSelection();

      expect(mockVscode.window.showWarningMessage).toHaveBeenCalledWith(
        expect.stringContaining('Environment scan timed out'),
        expect.any(String),
        expect.any(String)
      );
    });

    it('should handle user cancellation gracefully', async () => {
      mockEnvDetection.findPythonEnvsWithJac.mockRejectedValue(new Error('Cancelled by user'));
      mockVscode.window.withProgress.mockImplementation(async (options, task) => {
        throw new Error('Cancelled by user');
      });

      await manager.promptEnvironmentSelection();

      expect(mockVscode.window.showInformationMessage).toHaveBeenCalledWith(
        'Environment scan cancelled'
      );
    });
  });
});