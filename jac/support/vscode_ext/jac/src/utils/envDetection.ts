import * as fs from 'fs/promises';
import * as path from 'path';
import * as cp from 'child_process';
import { promisify } from 'util';

const exec = promisify(cp.exec);

// --- Constants ---
const JAC_EXECUTABLE_NIX = 'jac';
const JAC_EXECUTABLE_WIN = 'jac.exe';

const COMMON_VENV_NAMES = ['.venv', 'venv', 'env', '.env', 'virtualenv', 'pyenv'];

// Depth for recursive searches - limited to 2 levels max for fast performance
const WALK_DEPTH_WORKSPACE = 2;
const WALK_DEPTH_VIRTUALENVS = 2;



/**
 * Checks for a 'jac' executable in a given virtual environment directory.
 * @param venvPath The root path of the virtual environment.
 * @returns The full path to the 'jac' executable or null if not found.
 */
async function getJacInVenv(venvPath: string): Promise<string | null> {
    const jacPathNix = path.join(venvPath, 'bin', JAC_EXECUTABLE_NIX);
    if (await fileExists(jacPathNix)) return jacPathNix;

    const jacPathWin = path.join(venvPath, 'Scripts', JAC_EXECUTABLE_WIN);
    if (await fileExists(jacPathWin)) return jacPathWin;

    return null;
}

/**
 * Asynchronously walks a directory structure to a specified depth looking for venvs with jac.
 * Optimized to limit depth and avoid unnecessary deep recursion for better performance.
 * @param baseDir The directory to start from.
 * @param depth The maximum depth to recurse (max 2 for workspace efficiency).
 * @returns A promise that resolves to an array of jac executable paths.
 */
async function walkForVenvs(baseDir: string, depth: number): Promise<string[]> {
    if (depth === 0) return [];

    let entries: import('fs').Dirent[];

    try {
        entries = await fs.readdir(baseDir, { withFileTypes: true });
    } catch (error) {
        // Silently ignore permission errors, common in deep scans
        return [];
    }

    // Filter to only directories early to avoid unnecessary processing
    const directories = entries.filter(entry => entry.isDirectory());
    
    const promises: Promise<string[] | string | null>[] = directories.map(async (entry) => {
        const fullPath = path.join(baseDir, entry.name);
        
        // Check if this directory contains jac
        const foundJac = await getJacInVenv(fullPath);
        
        // Only recurse if we have depth remaining and didn't find jac here
        // This avoids deep searches in directories that already contain jac
        if (depth > 1 && !foundJac) {
            const deeperFinds = await walkForVenvs(fullPath, depth - 1);
            return deeperFinds;
        }
        
        return foundJac ? [foundJac] : [];
    });

    const results = await Promise.all(promises);
    return results.flat().filter(p => p !== null) as string[];
}

// --- Discovery Strategies ---

/**
 * Finds global jac installation using which/where command
 */
async function findGlobalJac(): Promise<string[]> {
    try {
        const command = process.platform === 'win32' ? 'where jac' : 'which jac';
        const { stdout } = await exec(command, { timeout: 5000 });
        const paths = stdout.trim().split('\n').filter(line => line.trim());
        
        // Validate each path found
        const validPaths = [];
        for (const jacPath of paths) {
            const trimmedPath = jacPath.trim();
            if (await validateJacExecutable(trimmedPath)) {
                validPaths.push(trimmedPath);
            }
        }
        return validPaths;
    } catch (error) {
        // Command failed - jac not in PATH or command doesn't exist
        return [];
    }
}

async function findInPath(): Promise<string[]> {
    const jacExe = process.platform === 'win32' ? JAC_EXECUTABLE_WIN : JAC_EXECUTABLE_NIX;
    const pathDirs = process.env.PATH?.split(path.delimiter) || [];
    const found = [];
    for (const dir of pathDirs) {
        const jacPath = path.join(dir, jacExe);
        if (await fileExists(jacPath)) {
            found.push(jacPath);
        }
    }
    return found;
}

async function findInCondaEnvs(): Promise<string[]> {
    try {
        const { stdout } = await exec('conda env list', { timeout: 5000 });
        const lines = stdout.split('\n').slice(2); // Skip header lines
        const promises = lines.map(async (line) => {
            const parts = line.trim().split(/\s+/);
            const envPath = parts[parts.length - 1]; // Path is the last part
            if (envPath) {
                return getJacInVenv(envPath);
            }
            return null;
        });
        const results = await Promise.all(promises);
        return results.filter(p => p !== null) as string[];
    } catch (error) {
        // Conda not found or command failed, which is a normal scenario.
        return [];
    }
}

async function findInWorkspace(workspaceRoot: string): Promise<string[]> {
    const searchTasks: Promise<string[]>[] = [];

    // 1. Check common venv names in the workspace root
    for (const dirName of COMMON_VENV_NAMES) {
        searchTasks.push(getJacInVenv(path.join(workspaceRoot, dirName)).then(p => p ? [p] : []));
    }
    
    // 2. Limited search in workspace root only (2 levels deep max)
    searchTasks.push(walkForVenvs(workspaceRoot, WALK_DEPTH_WORKSPACE));

    const results = await Promise.all(searchTasks);
    return results.flat();
}

async function findInHome(workspaceRoot: string): Promise<string[]> {
    // Only check virtualenvwrapper directory for better performance
    // Skip deep home directory scans to focus on workspace-local environments
    const homeDir = process.env.HOME || process.env.USERPROFILE;
    if (!homeDir || homeDir === workspaceRoot) return [];

    const venvWrapperDir = path.join(homeDir, '.virtualenvs');
    if (await directoryExists(venvWrapperDir)) {
        return await walkForVenvs(venvWrapperDir, WALK_DEPTH_VIRTUALENVS);
    }
    
    return [];
}


/**
 * Finds all Python environments with the 'jac' executable.
 * Fast and optimized for instant results by limiting workspace search to 2 levels deep
 * and focusing on workspace-local environments similar to Python's VS Code extension.
 *
 * @param workspaceRoot The root directory of the workspace to scan. Defaults to the current working directory.
 * @returns A promise that resolves to a unique array of paths to 'jac' executables.
 */
export async function findPythonEnvsWithJac(workspaceRoot: string = process.cwd()): Promise<string[]> {
    // Run optimized discovery strategies in parallel for instant results
    // Promise.allSettled ensures that if one strategy fails (e.g., conda not installed), the others can still succeed.
    const results = await Promise.allSettled([
        findGlobalJac(),      // Check for global jac first (most reliable)
        findInPath(),         // Manual PATH scanning (backup)
        findInCondaEnvs(),    // Conda environments
        findInWorkspace(workspaceRoot), // Workspace-local environments (2 levels deep max)
        findInHome(workspaceRoot) // Only virtualenvwrapper, no deep home scan
    ]);

    const allEnvs: string[] = [];
    for (const result of results) {
        if (result.status === 'fulfilled' && result.value) {
            allEnvs.push(...result.value);
        }
        // Silently handle failures for cleaner UX since search is now instant
    }

    // Deduplicate and return immediately
    return Array.from(new Set(allEnvs));
}

// --- Utility Helpers ---

async function fileExists(filePath: string): Promise<boolean> {
    try {
        await fs.access(filePath, fs.constants.F_OK);
        return true;
    } catch {
        return false;
    }
}

async function directoryExists(dirPath: string): Promise<boolean> {
    try {
        const stat = await fs.stat(dirPath);
        return stat.isDirectory();
    } catch {
        return false;
    }
}

/**
 * Validates if a given Jac executable path is working.
 * @param jacPath The path to the Jac executable to validate.
 * @returns Promise<boolean> True if the executable exists and responds to --version.
 */
export async function validateJacExecutable(jacPath: string): Promise<boolean> {
    try {
        const { stdout } = await exec(`"${jacPath}" --version`, { timeout: 5000 });
        return stdout.includes('jac') || stdout.includes('Jac');
    } catch (error) {
        return false;
    }
}