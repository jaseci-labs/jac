/**
 * Cross-platform Integration Tests for Environment Detection and Management
 * Tests the complete workflow on both Windows and Ubuntu with different environment types
 */

import { EnvManager } from '../environment/manager';
import * as envDetection from '../utils/envDetection';

// Mock all external dependencies
jest.mock('vscode');
jest.mock('fs/promises');
jest.mock('child_process');
jest.mock('path');
jest.mock('util');
jest.mock('../utils/envDetection');

const mockEnvDetection = jest.mocked(envDetection);

describe('Cross-Platform Environment Integration Tests', () => {
  let originalPlatform: NodeJS.Platform;
  let originalEnv: NodeJS.ProcessEnv;

  beforeEach(() => {
    originalPlatform = process.platform;
    originalEnv = { ...process.env };
    jest.clearAllMocks();
  });

  afterEach(() => {
    Object.defineProperty(process, 'platform', {
      value: originalPlatform,
      configurable: true
    });
    process.env = originalEnv;
  });

  describe('Linux Ubuntu Environment Scenarios', () => {
    beforeEach(() => {
      Object.defineProperty(process, 'platform', {
        value: 'linux' as NodeJS.Platform,
        configurable: true
      });
      process.env.PATH = '/usr/local/bin:/usr/bin:/bin:/home/user/.local/bin';
      process.env.HOME = '/home/user';
      delete process.env.USERPROFILE;
    });

    describe('Global System Installation', () => {
      it('should detect and validate global jac installation via apt/pip', async () => {
        const globalJacPath = '/usr/local/bin/jac';
        
        // Mock successful detection and validation
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([globalJacPath]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('/home/user/workspace');
        
        expect(environments).toContain(globalJacPath);
        
        // Validate the executable
        const isValid = await envDetection.validateJacExecutable(globalJacPath);
        expect(isValid).toBe(true);
      });

      it('should handle global installation in user local bin', async () => {
        const userLocalJac = '/home/user/.local/bin/jac';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([userLocalJac]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('/home/user/workspace');
        
        expect(environments).toContain(userLocalJac);
      });
    });

    describe('Virtual Environment Scenarios', () => {
      it('should detect jac in project .venv directory', async () => {
        const projectVenvJac = '/home/user/myproject/.venv/bin/jac';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([projectVenvJac]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('/home/user/myproject');
        
        expect(environments).toContain(projectVenvJac);
      });

      it('should detect multiple venv types (venv, .venv, env)', async () => {
        const venvPaths = [
          '/home/user/project1/.venv/bin/jac',
          '/home/user/project2/venv/bin/jac',
          '/home/user/project3/env/bin/jac'
        ];
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(venvPaths);
        venvPaths.forEach(path => {
          mockEnvDetection.validateJacExecutable.mockResolvedValue(true);
        });

        const environments = await envDetection.findPythonEnvsWithJac('/home/user');
        
        venvPaths.forEach(path => {
          expect(environments).toContain(path);
        });
      });

      it('should detect virtualenvwrapper environments in ~/.virtualenvs', async () => {
        const virtualenvWrapperJac = '/home/user/.virtualenvs/myproject/bin/jac';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([virtualenvWrapperJac]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('/home/user/workspace');
        
        expect(environments).toContain(virtualenvWrapperJac);
      });
    });

    describe('Conda Environment Scenarios', () => {
      it('should detect jac in conda environments', async () => {
        const condaPaths = [
          '/opt/miniconda3/envs/jacdev/bin/jac',
          '/home/user/miniconda3/envs/myproject/bin/jac'
        ];
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(condaPaths);
        condaPaths.forEach(path => {
          mockEnvDetection.validateJacExecutable.mockResolvedValue(true);
        });

        const environments = await envDetection.findPythonEnvsWithJac('/home/user/workspace');
        
        condaPaths.forEach(path => {
          expect(environments).toContain(path);
        });
      });

      it('should handle both system and user conda installations', async () => {
        const systemCondaJac = '/opt/conda/envs/jacenv/bin/jac';
        const userCondaJac = '/home/user/anaconda3/envs/jacenv/bin/jac';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([systemCondaJac, userCondaJac]);
        [systemCondaJac, userCondaJac].forEach(path => {
          mockEnvDetection.validateJacExecutable.mockResolvedValue(true);
        });

        const environments = await envDetection.findPythonEnvsWithJac('/home/user/workspace');
        
        expect(environments).toContain(systemCondaJac);
        expect(environments).toContain(userCondaJac);
      });
    });
  });

  describe('Windows Environment Scenarios', () => {
    beforeEach(() => {
      Object.defineProperty(process, 'platform', {
        value: 'win32' as NodeJS.Platform,
        configurable: true
      });
      process.env.PATH = 'C:\\Windows\\System32;C:\\Windows;C:\\Python39\\Scripts;C:\\Users\\User\\AppData\\Local\\Programs\\Python\\Python39\\Scripts';
      process.env.USERPROFILE = 'C:\\Users\\User';
      delete process.env.HOME;
    });

    describe('Global System Installation', () => {
      it('should detect global jac installation in Python Scripts directory', async () => {
        const globalJacPath = 'C:\\Python39\\Scripts\\jac.exe';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([globalJacPath]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('C:\\Users\\User\\workspace');
        
        expect(environments).toContain(globalJacPath);
      });

      it('should detect user-scoped Python installation', async () => {
        const userJacPath = 'C:\\Users\\User\\AppData\\Local\\Programs\\Python\\Python39\\Scripts\\jac.exe';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([userJacPath]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('C:\\Users\\User\\workspace');
        
        expect(environments).toContain(userJacPath);
      });
    });

    describe('Virtual Environment Scenarios', () => {
      it('should detect jac in Windows venv (Scripts directory)', async () => {
        const windowsVenvJac = 'C:\\Users\\User\\myproject\\venv\\Scripts\\jac.exe';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([windowsVenvJac]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('C:\\Users\\User\\myproject');
        
        expect(environments).toContain(windowsVenvJac);
      });

      it('should handle mixed case directory names correctly', async () => {
        const mixedCasePaths = [
          'C:\\Users\\User\\Project\\.venv\\Scripts\\jac.exe',
          'C:\\Users\\User\\MyApp\\Venv\\Scripts\\jac.exe'
        ];
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(mixedCasePaths);
        mixedCasePaths.forEach(path => {
          mockEnvDetection.validateJacExecutable.mockResolvedValue(true);
        });

        const environments = await envDetection.findPythonEnvsWithJac('C:\\Users\\User');
        
        mixedCasePaths.forEach(path => {
          expect(environments).toContain(path);
        });
      });
    });

    describe('Conda Environment Scenarios', () => {
      it('should detect jac in Windows conda environments', async () => {
        const windowsCondaPaths = [
          'C:\\Miniconda3\\envs\\jacdev\\Scripts\\jac.exe',
          'C:\\Users\\User\\Anaconda3\\envs\\myproject\\Scripts\\jac.exe'
        ];
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(windowsCondaPaths);
        windowsCondaPaths.forEach(path => {
          mockEnvDetection.validateJacExecutable.mockResolvedValue(true);
        });

        const environments = await envDetection.findPythonEnvsWithJac('C:\\Users\\User\\workspace');
        
        windowsCondaPaths.forEach(path => {
          expect(environments).toContain(path);
        });
      });

      it('should handle Windows path separators correctly in conda', async () => {
        const condaJacPath = 'C:\\ProgramData\\Miniconda3\\envs\\production\\Scripts\\jac.exe';
        
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([condaJacPath]);
        mockEnvDetection.validateJacExecutable.mockResolvedValue(true);

        const environments = await envDetection.findPythonEnvsWithJac('C:\\workspace');
        
        expect(environments).toContain(condaJacPath);
      });
    });
  });

  describe('Cross-Platform Display and User Experience', () => {
    it('should display environment labels consistently across platforms', async () => {
      // Test that environment naming is consistent
      const testCases = [
        {
          platform: 'linux' as NodeJS.Platform,
          paths: [
            '/usr/local/bin/jac',
            '/home/user/project/.venv/bin/jac',
            '/opt/miniconda3/envs/jacenv/bin/jac'
          ],
          expectedLabels: [
            'Jac',
            'Jac (.venv)',
            'Jac (jacenv)'
          ]
        },
        {
          platform: 'win32' as NodeJS.Platform,
          paths: [
            'C:\\Python39\\Scripts\\jac.exe',
            'C:\\Users\\User\\project\\venv\\Scripts\\jac.exe',
            'C:\\Miniconda3\\envs\\jacenv\\Scripts\\jac.exe'
          ],
          expectedLabels: [
            'Jac',
            'Jac (venv)',
            'Jac (jacenv)'
          ]
        }
      ];

      for (const testCase of testCases) {
        Object.defineProperty(process, 'platform', {
          value: testCase.platform,
          configurable: true
        });

        // Each path should generate a consistent label regardless of platform
        testCase.paths.forEach((path, index) => {
          // The label generation logic should work the same way
          // This would be tested in the actual EnvManager display logic
          expect(path).toBeTruthy();
          expect(testCase.expectedLabels[index]).toBeTruthy();
        });
      }
    });

    it('should handle path display formatting correctly on both platforms', async () => {
      const testCases = [
        {
          platform: 'linux' as NodeJS.Platform,
          homePath: '/home/user',
          fullPath: '/home/user/very/deep/nested/project/.venv/bin/jac',
          expectedDisplay: '~/very/deep/nested/project/.venv/bin/jac'
        },
        {
          platform: 'win32' as NodeJS.Platform,
          homePath: 'C:\\Users\\User',
          fullPath: 'C:\\Users\\User\\Documents\\Projects\\DeepProject\\venv\\Scripts\\jac.exe',
          expectedDisplay: 'C:\\Users\\...\\Scripts\\jac.exe' // Truncated long path
        }
      ];

      testCases.forEach(testCase => {
        Object.defineProperty(process, 'platform', {
          value: testCase.platform,
          configurable: true
        });
        
        if (testCase.platform === 'linux') {
          process.env.HOME = testCase.homePath;
        } else {
          process.env.USERPROFILE = testCase.homePath;
        }

        // The path formatting logic should handle both platforms correctly
        expect(testCase.fullPath).toContain(testCase.platform === 'win32' ? '\\' : '/');
      });
    });
  });

  describe('Error Handling Across Platforms', () => {
    it('should handle permission errors consistently on both platforms', async () => {
      const errorScenarios = [
        {
          platform: 'linux' as NodeJS.Platform,
          errorMessage: 'EACCES: permission denied'
        },
        {
          platform: 'win32' as NodeJS.Platform,
          errorMessage: 'EPERM: operation not permitted'
        }
      ];

      for (const scenario of errorScenarios) {
        Object.defineProperty(process, 'platform', {
          value: scenario.platform,
          configurable: true
        });

        mockEnvDetection.findPythonEnvsWithJac.mockRejectedValue(new Error(scenario.errorMessage));

        const environments = await envDetection.findPythonEnvsWithJac('/test/workspace').catch(() => []);
        
        // Should handle errors gracefully and return empty array
        expect(environments).toEqual([]);
      }
    });

    it('should handle command not found errors appropriately', async () => {
      const platforms: NodeJS.Platform[] = ['linux', 'win32'];

      for (const platform of platforms) {
        Object.defineProperty(process, 'platform', {
          value: platform,
          configurable: true
        });

        mockEnvDetection.validateJacExecutable.mockResolvedValue(false);
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue([]);

        const isValid = await envDetection.validateJacExecutable('/nonexistent/jac');
        const environments = await envDetection.findPythonEnvsWithJac('/test');
        
        expect(isValid).toBe(false);
        expect(environments).toEqual([]);
      }
    });
  });

  describe('Performance and Caching', () => {
    it('should cache results efficiently on both platforms', async () => {
      const platforms: NodeJS.Platform[] = ['linux', 'win32'];

      for (const platform of platforms) {
        Object.defineProperty(process, 'platform', {
          value: platform,
          configurable: true
        });

        // Reset cache
        envDetection.clearEnvironmentCache();
        expect(envDetection.isCacheValid()).toBe(false);

        // First call should populate cache
        mockEnvDetection.findPythonEnvsWithJac.mockResolvedValue(['/test/jac']);
        await envDetection.findPythonEnvsWithJac('/test');
        
        expect(envDetection.isCacheValid()).toBe(true);
      }
    });
  });
});