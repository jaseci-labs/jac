/**
 * Test utilities and mock helpers for VSCode extension testing
 */

export class MockUtils {
  /**
   * Create mock functions for different platforms
   */
  static createPlatformMocks() {
    return {
      setWindows: () => {
        Object.defineProperty(process, 'platform', {
          value: 'win32',
          writable: true,
          configurable: true
        });
        process.env.PATH = 'C:\\Windows\\System32;C:\\Windows;C:\\Python39\\Scripts';
        process.env.HOME = undefined;
        process.env.USERPROFILE = 'C:\\Users\\TestUser';
      },
      setLinux: () => {
        Object.defineProperty(process, 'platform', {
          value: 'linux',
          writable: true,
          configurable: true
        });
        process.env.PATH = '/usr/local/bin:/usr/bin:/bin';
        process.env.HOME = '/home/testuser';
        process.env.USERPROFILE = undefined;
      }
    };
  }

  /**
   * Create mock VSCode context
   */
  static createMockContext() {
    const globalState = {
      get: jest.fn(),
      update: jest.fn()
    };

    return {
      globalState,
      subscriptions: []
    };
  }

  /**
   * Create mock status bar item
   */
  static createMockStatusBarItem() {
    return {
      text: '',
      tooltip: '',
      command: '',
      show: jest.fn(),
      hide: jest.fn(),
      dispose: jest.fn()
    };
  }

  /**
   * Create mock VSCode window
   */
  static createMockWindow() {
    const statusBarItem = MockUtils.createMockStatusBarItem();
    
    return {
      createStatusBarItem: jest.fn(() => statusBarItem),
      showQuickPick: jest.fn(),
      showInputBox: jest.fn(),
      showOpenDialog: jest.fn(),
      showInformationMessage: jest.fn(),
      showWarningMessage: jest.fn(),
      showErrorMessage: jest.fn(),
      withProgress: jest.fn(),
      statusBarItem
    };
  }

  /**
   * Create file system mocks for different environment scenarios
   */
  static createFsMocks() {
    return {
      // Mock for global jac in PATH
      mockGlobalJac: (exists = true) => {
        const fs = require('fs/promises');
        fs.access.mockImplementation((path: string) => {
          if ((path.includes('jac') || path.includes('jac.exe')) && exists) {
            return Promise.resolve();
          }
          return Promise.reject(new Error('ENOENT'));
        });
      },

      // Mock for venv scenarios
      mockVenvStructure: (paths: { [key: string]: boolean }) => {
        const fs = require('fs/promises');
        
        fs.readdir.mockImplementation((dirPath: string) => {
          if (dirPath.includes('.venv') || dirPath.includes('venv')) {
            return Promise.resolve([
              { name: 'bin', isDirectory: () => true },
              { name: 'lib', isDirectory: () => true },
              { name: 'Scripts', isDirectory: () => true } // Windows
            ]);
          }
          return Promise.resolve([]);
        });

        fs.access.mockImplementation((path: string) => {
          const exists = Object.keys(paths).some(p => path.includes(p) && paths[p]);
          return exists ? Promise.resolve() : Promise.reject(new Error('ENOENT'));
        });

        fs.stat.mockImplementation((path: string) => {
          return Promise.resolve({ isDirectory: () => true });
        });
      },

      // Mock for conda scenarios
      mockCondaEnvironments: (envs: string[]) => {
        const cp = require('child_process');
        const output = [
          '# conda environments:',
          '#',
          ...envs.map(env => `${env}                  ${env}`)
        ].join('\n');
        
        cp.exec.mockImplementation((command: string, options: any, callback?: Function) => {
          if (command === 'conda env list') {
            if (callback) {
              callback(null, { stdout: output, stderr: '' });
            }
            return Promise.resolve({ stdout: output, stderr: '' });
          }
          return Promise.reject(new Error('Command not found'));
        });
      }
    };
  }

  /**
   * Create exec mocks for different scenarios
   */
  static createExecMocks() {
    return {
      mockJacVersion: (jacPath: string, success = true) => {
        const cp = require('child_process');
        cp.exec.mockImplementation((command: string, options: any) => {
          if (command.includes('--version')) {
            if (success) {
              return Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' });
            } else {
              return Promise.reject(new Error('Command failed'));
            }
          }
          return Promise.reject(new Error('Unknown command'));
        });
      },

      mockWhichCommand: (platform: 'win32' | 'linux', jacPaths: string[] = []) => {
        const cp = require('child_process');
        const command = platform === 'win32' ? 'where jac' : 'which jac';
        
        cp.exec.mockImplementation((cmd: string, options: any) => {
          if (cmd === command) {
            if (jacPaths.length > 0) {
              return Promise.resolve({ stdout: jacPaths.join('\n') + '\n', stderr: '' });
            } else {
              return Promise.reject(new Error('jac not found'));
            }
          }
          return Promise.reject(new Error('Command not found'));
        });
      }
    };
  }

  /**
   * Create path mocks for different platforms
   */
  static createPathMocks(platform: 'win32' | 'linux') {
    const path = require('path');
    
    if (platform === 'win32') {
      path.join.mockImplementation((...args: string[]) => args.join('\\'));
      path.sep = '\\';
      path.delimiter = ';';
      path.dirname.mockImplementation((p: string) => {
        const parts = p.split('\\');
        return parts.slice(0, -1).join('\\');
      });
      path.basename.mockImplementation((p: string) => {
        const parts = p.split('\\');
        return parts[parts.length - 1];
      });
    } else {
      path.join.mockImplementation((...args: string[]) => args.join('/'));
      path.sep = '/';
      path.delimiter = ':';
      path.dirname.mockImplementation((p: string) => {
        const parts = p.split('/');
        return parts.slice(0, -1).join('/');
      });
      path.basename.mockImplementation((p: string) => {
        const parts = p.split('/');
        return parts[parts.length - 1];
      });
    }
    
    path.isAbsolute.mockImplementation((p: string) => {
      return platform === 'win32' ? /^[A-Za-z]:/.test(p) : p.startsWith('/');
    });
  }

  /**
   * Reset all mocks to clean state
   */
  static resetAllMocks() {
    jest.clearAllMocks();
    
    // Reset process.env
    process.env.PATH = '/usr/local/bin:/usr/bin:/bin';
    process.env.HOME = '/home/testuser';
    delete process.env.USERPROFILE;
    
    // Reset platform
    Object.defineProperty(process, 'platform', {
      value: 'linux',
      writable: true,
      configurable: true
    });
  }
}