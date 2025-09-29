/**
 * Tests for envDetection.ts - Environment Discovery Functions
 */

// Mock external dependencies
jest.mock('fs/promises');
jest.mock('child_process');
jest.mock('path');
jest.mock('util');

import * as fs from 'fs/promises';
import * as cp from 'child_process';
import * as path from 'path';
import { promisify } from 'util';

// Import functions to test
// Import functions to test
import { 
  findPythonEnvsWithJac,
  clearEnvironmentCache,
  isCacheValid,
  validateJacExecutable
} from '../utils/envDetection';

const mockFs = jest.mocked(fs);
const mockCp = jest.mocked(cp);
const mockPath = jest.mocked(path);
const mockUtil = jest.mocked({ promisify });

describe('envDetection.ts', () => {
  let originalPlatform: NodeJS.Platform;
  let originalEnv: NodeJS.ProcessEnv;

  beforeEach(() => {
    // Store original values
    originalPlatform = process.platform;
    originalEnv = { ...process.env };
    
    // Reset mocks
    jest.clearAllMocks();
    clearEnvironmentCache();
    
    // Default to Linux setup
    setupLinuxEnvironment();
  });

  afterEach(() => {
    // Restore original values
    Object.defineProperty(process, 'platform', {
      value: originalPlatform,
      configurable: true
    });
    process.env = originalEnv;
  });

  function setupLinuxEnvironment() {
    Object.defineProperty(process, 'platform', {
      value: 'linux' as NodeJS.Platform,
      configurable: true
    });
    
    process.env.PATH = '/usr/local/bin:/usr/bin:/bin';
    process.env.HOME = '/home/testuser';
    delete process.env.USERPROFILE;
    
    // Mock path functions for Linux
    mockPath.join.mockImplementation((...args: string[]) => args.join('/'));
    Object.defineProperty(mockPath, 'sep', { value: '/', writable: true, configurable: true });
    Object.defineProperty(mockPath, 'delimiter', { value: ':', writable: true, configurable: true });
    mockPath.dirname.mockImplementation((p: string) => {
      const parts = p.split('/');
      return parts.slice(0, -1).join('/');
    });
    mockPath.basename.mockImplementation((p: string) => {
      const parts = p.split('/');
      return parts[parts.length - 1];
    });
    mockPath.isAbsolute.mockImplementation((p: string) => p.startsWith('/'));
  }

  function setupWindowsEnvironment() {
    Object.defineProperty(process, 'platform', {
      value: 'win32' as NodeJS.Platform,
      configurable: true
    });
    
    process.env.PATH = 'C:\\Windows\\System32;C:\\Windows;C:\\Python39\\Scripts';
    process.env.USERPROFILE = 'C:\\Users\\TestUser';
    delete process.env.HOME;
    
    // Mock path functions for Windows
    mockPath.join.mockImplementation((...args: string[]) => args.join('\\'));
    Object.defineProperty(mockPath, 'sep', { value: '\\', writable: true, configurable: true });
    Object.defineProperty(mockPath, 'delimiter', { value: ';', writable: true, configurable: true });
    mockPath.dirname.mockImplementation((p: string) => {
      const parts = p.split('\\');
      return parts.slice(0, -1).join('\\');
    });
    mockPath.basename.mockImplementation((p: string) => {
      const parts = p.split('\\');
      return parts[parts.length - 1];
    });
    mockPath.isAbsolute.mockImplementation((p: string) => /^[A-Za-z]:/.test(p));
  }

  describe('validateJacExecutable', () => {
    it('should validate working jac executable', async () => {
      // Mock the promisified exec function
      const mockExecAsync = jest.fn().mockResolvedValue({
        stdout: 'jac 0.7.0\n',
        stderr: ''
      });
      
      mockUtil.promisify.mockReturnValue(mockExecAsync);

      const result = await validateJacExecutable('/usr/local/bin/jac');
      
      expect(result).toBe(true);
      expect(mockExecAsync).toHaveBeenCalledWith('"/usr/local/bin/jac" --version', { timeout: 5000 });
    });

    it('should reject non-working jac executable', async () => {
      const mockExec = jest.fn().mockRejectedValue(new Error('Command not found'));
      
      (cp.exec as any) = mockExec;

      const result = await validateJacExecutable('/invalid/path/jac');
      
      expect(result).toBe(false);
    });

    it('should validate jac output containing "Jac"', async () => {
      const mockExec = jest.fn().mockResolvedValue({
        stdout: 'Jac Language Server 0.7.0\n',
        stderr: ''
      });
      
      (cp.exec as any) = mockExec;

      const result = await validateJacExecutable('/usr/local/bin/jac');
      expect(result).toBe(true);
    });
  });

  describe('Cache Management', () => {
    it('should indicate cache is invalid initially', () => {
      expect(isCacheValid()).toBe(false);
    });

    it('should cache results for 10 seconds', async () => {
      // Mock successful environment discovery
      mockSuccessfulDiscovery();
      
      const result1 = await findPythonEnvsWithJac('/test/workspace');
      expect(isCacheValid()).toBe(true);
      
      // Second call should use cache
      const result2 = await findPythonEnvsWithJac('/test/workspace');
      expect(result1).toEqual(result2);
    });

    it('should clear cache when requested', () => {
      // Set up cache
      findPythonEnvsWithJac('/test/workspace');
      expect(isCacheValid()).toBe(true);
      
      clearEnvironmentCache();
      expect(isCacheValid()).toBe(false);
    });
  });

  describe('Linux Environment Discovery', () => {
    beforeEach(() => {
      setupLinuxEnvironment();
    });

    it('should find global jac using which command', async () => {
      const mockExec = jest.fn()
        .mockImplementationOnce(() => Promise.resolve({
          stdout: '/usr/local/bin/jac\n',
          stderr: ''
        }))
        .mockImplementationOnce(() => Promise.resolve({
          stdout: 'jac 0.7.0\n',
          stderr: ''
        }));
      
      (cp.exec as any) = mockExec;

      const result = await findPythonEnvsWithJac('/test/workspace');
      
      expect(result).toContain('/usr/local/bin/jac');
      expect(mockExec).toHaveBeenCalledWith('which jac', { timeout: 5000 });
    });

    it('should find jac in PATH directories', async () => {
      // Mock fs.access to simulate jac exists in /usr/bin
      mockFs.access.mockImplementation((filePath: any) => {
        if (filePath === '/usr/bin/jac') {
          return Promise.resolve();
        }
        return Promise.reject(new Error('ENOENT'));
      });

      // Mock exec to fail which command but succeed validation
      const mockExec = jest.fn()
        .mockImplementationOnce(() => Promise.reject(new Error('jac not found'))) // which fails
        .mockImplementationOnce(() => Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' })); // validation succeeds
      
      (cp.exec as any) = mockExec;

      const result = await findPythonEnvsWithJac('/test/workspace');
      
      expect(result).toContain('/usr/bin/jac');
    });

    it('should find jac in virtual environments', async () => {
      // Mock directory structure for .venv
      mockFs.readdir.mockImplementation((dirPath: any) => {
        if (dirPath.includes('.venv')) {
          return Promise.resolve([
            { name: 'bin', isDirectory: () => true } as any,
            { name: 'lib', isDirectory: () => true } as any
          ]);
        }
        return Promise.resolve([]);
      });

      // Mock jac exists in venv
      mockFs.access.mockImplementation((filePath: any) => {
        if (filePath.includes('/.venv/bin/jac')) {
          return Promise.resolve();
        }
        return Promise.reject(new Error('ENOENT'));
      });

      mockFs.stat.mockResolvedValue({ isDirectory: () => true } as any);

      // Mock validation
      const mockExec = jest.fn()
        .mockImplementation(() => Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' }));
      (cp.exec as any) = mockExec;

      const result = await findPythonEnvsWithJac('/test/workspace');
      
      expect(result.some(path => path.includes('.venv/bin/jac'))).toBe(true);
    });

    it('should find jac in conda environments', async () => {
      const condaOutput = `# conda environments:
#
base                     /opt/miniconda3
myenv                    /opt/miniconda3/envs/myenv
jacenv                   /opt/miniconda3/envs/jacenv
`;

      // Mock conda command
      const mockExec = jest.fn()
        .mockImplementationOnce(() => Promise.resolve({ stdout: condaOutput, stderr: '' }))
        .mockImplementation(() => Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' }));
      
      (cp.exec as any) = mockExec;

      // Mock jac exists in conda env
      mockFs.access.mockImplementation((filePath: any) => {
        if (filePath.includes('/opt/miniconda3/envs/jacenv/bin/jac')) {
          return Promise.resolve();
        }
        return Promise.reject(new Error('ENOENT'));
      });

      const result = await findPythonEnvsWithJac('/test/workspace');
      
      expect(result.some(path => path.includes('jacenv/bin/jac'))).toBe(true);
    });
  });

  describe('Windows Environment Discovery', () => {
    beforeEach(() => {
      setupWindowsEnvironment();
    });

    it('should find global jac using where command on Windows', async () => {
      const mockExec = jest.fn()
        .mockImplementationOnce(() => Promise.resolve({
          stdout: 'C:\\Python39\\Scripts\\jac.exe\n',
          stderr: ''
        }))
        .mockImplementationOnce(() => Promise.resolve({
          stdout: 'jac 0.7.0\n',
          stderr: ''
        }));
      
      (cp.exec as any) = mockExec;

      const result = await findPythonEnvsWithJac('C:\\test\\workspace');
      
      expect(result).toContain('C:\\Python39\\Scripts\\jac.exe');
      expect(mockExec).toHaveBeenCalledWith('where jac', { timeout: 5000 });
    });

    it('should find jac in Windows virtual environments', async () => {
      // Mock directory structure for venv on Windows
      mockFs.readdir.mockImplementation((dirPath: any) => {
        if (dirPath.includes('venv')) {
          return Promise.resolve([
            { name: 'Scripts', isDirectory: () => true } as any,
            { name: 'Lib', isDirectory: () => true } as any
          ]);
        }
        return Promise.resolve([]);
      });

      // Mock jac.exe exists in Scripts folder
      mockFs.access.mockImplementation((filePath: any) => {
        if (filePath.includes('\\venv\\Scripts\\jac.exe')) {
          return Promise.resolve();
        }
        return Promise.reject(new Error('ENOENT'));
      });

      mockFs.stat.mockResolvedValue({ isDirectory: () => true } as any);

      // Mock validation
      const mockExec = jest.fn()
        .mockImplementation(() => Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' }));
      (cp.exec as any) = mockExec;

      const result = await findPythonEnvsWithJac('C:\\test\\workspace');
      
      expect(result.some(path => path.includes('venv\\Scripts\\jac.exe'))).toBe(true);
    });

    it('should handle Windows conda environments', async () => {
      const condaOutput = `# conda environments:
#
base                     C:\\Miniconda3
myenv                    C:\\Miniconda3\\envs\\myenv
jacenv                   C:\\Miniconda3\\envs\\jacenv
`;

      const mockExec = jest.fn()
        .mockImplementationOnce(() => Promise.resolve({ stdout: condaOutput, stderr: '' }))
        .mockImplementation(() => Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' }));
      
      (cp.exec as any) = mockExec;

      // Mock jac.exe exists in conda Scripts folder
      mockFs.access.mockImplementation((filePath: any) => {
        if (filePath.includes('jacenv\\Scripts\\jac.exe')) {
          return Promise.resolve();
        }
        return Promise.reject(new Error('ENOENT'));
      });

      const result = await findPythonEnvsWithJac('C:\\test\\workspace');
      
      expect(result.some(path => path.includes('jacenv\\Scripts\\jac.exe'))).toBe(true);
    });
  });

  describe('Error Handling', () => {
    it('should handle failed discovery strategies gracefully', async () => {
      // Mock all discovery methods to fail
      const mockExec = jest.fn().mockRejectedValue(new Error('Command failed'));
      (cp.exec as any) = mockExec;

      mockFs.access.mockRejectedValue(new Error('ENOENT'));
      mockFs.readdir.mockRejectedValue(new Error('EACCES'));

      const result = await findPythonEnvsWithJac('/test/workspace');
      
      expect(result).toEqual([]);
    });

    it('should continue discovery even if one strategy fails', async () => {
      // Mock global discovery to fail but PATH discovery to succeed
      const mockExec = jest.fn()
        .mockImplementationOnce(() => Promise.reject(new Error('which failed')))
        .mockImplementationOnce(() => Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' }));
      
      (cp.exec as any) = mockExec;

      mockFs.access.mockImplementation((filePath: any) => {
        if (filePath === '/usr/bin/jac') {
          return Promise.resolve();
        }
        return Promise.reject(new Error('ENOENT'));
      });

      const result = await findPythonEnvsWithJac('/test/workspace');
      
      expect(result).toContain('/usr/bin/jac');
    });
  });

  // Helper function to mock successful discovery
  function mockSuccessfulDiscovery() {
    const mockExec = jest.fn()
      .mockImplementation(() => Promise.resolve({ stdout: 'jac 0.7.0\n', stderr: '' }));
    (cp.exec as any) = mockExec;

    mockFs.access.mockImplementation((filePath: any) => {
      if (filePath.includes('jac')) {
        return Promise.resolve();
      }
      return Promise.reject(new Error('ENOENT'));
    });
  }
});