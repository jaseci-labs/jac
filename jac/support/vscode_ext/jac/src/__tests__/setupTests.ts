/**
 * Test setup file - runs before all tests
 */

// Setup global test environment
beforeEach(() => {
  // Reset all mocks
  jest.clearAllMocks();
  
  // Reset environment variables
  process.env = {
    ...process.env,
    PATH: '/usr/local/bin:/usr/bin:/bin',
    HOME: '/home/testuser'
  };
  
  // Reset platform
  Object.defineProperty(process, 'platform', {
    value: 'linux' as NodeJS.Platform,
    writable: true,
    configurable: true
  });
});

afterEach(() => {
  jest.restoreAllMocks();
});