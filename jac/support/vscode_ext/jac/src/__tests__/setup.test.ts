/**
 * Simple demo test to verify Jest setup and basic functionality
 */

describe('Basic Test Setup', () => {
  it('should run basic Jest functionality', () => {
    expect(1 + 1).toBe(2);
  });

  it('should handle mock functions', () => {
    const mockFn = jest.fn();
    mockFn('test');
    expect(mockFn).toHaveBeenCalledWith('test');
  });

  it('should test platform detection mocking', () => {
    const originalPlatform = process.platform;
    
    Object.defineProperty(process, 'platform', {
      value: 'win32' as NodeJS.Platform,
      configurable: true
    });
    
    expect(process.platform).toBe('win32');
    
    // Restore
    Object.defineProperty(process, 'platform', {
      value: originalPlatform,
      configurable: true
    });
  });

  it('should test environment variable mocking', () => {
    const originalEnv = process.env.PATH;
    
    process.env.PATH = '/custom/test/path';
    expect(process.env.PATH).toBe('/custom/test/path');
    
    // Restore
    process.env.PATH = originalEnv;
  });
});