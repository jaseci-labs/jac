/**
 * Version handling utilities for Mike-based documentation
 */

window.VersionHandler = {
    /**
     * Get the current version from the URL
     */
    getCurrentVersion: function() {
        const path = window.location.pathname;

        // For development server (localhost:8000), always return 'latest'
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            return 'latest';
        }

        // Handle versioned URLs like /v1.0.0/... or /latest/...
        const versionMatch = path.match(/^\/([^\/]+)/);

        if (!versionMatch || versionMatch[1] === 'docs' || versionMatch[1] === '') {
            return 'latest';
        }

        const version = versionMatch[1];

        // If it's a semantic version (v1.0.0 format), return as-is
        if (version.match(/^v\d+\.\d+\.\d+/)) {
            return version;
        }

        // If it's 'latest' or similar, return as-is
        if (['latest', 'main', 'dev', 'development'].includes(version.toLowerCase())) {
            return 'latest';
        }

        // For other formats, assume it's latest
        return 'latest';
    },

    /**
     * Switch to a different version
     */
    switchToVersion: function(version) {
        const currentVersion = this.getCurrentVersion();

        // Don't switch if already on the target version
        if (currentVersion === version) {
            return;
        }

        // For development server, just reload the page since all versions point to same content
        if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
            console.log(`Version switch requested to ${version}, but development server serves latest only`);
            return;
        }

        const currentPath = window.location.pathname;
        let newPath;

        if (version === 'latest') {
            // Remove version prefix to go to latest
            newPath = currentPath.replace(/^\/[^\/]+/, '') || '/';
        } else {
            if (currentVersion === 'latest') {
                // Add version prefix
                newPath = `/${version}${currentPath}`;
            } else {
                // Replace current version with new version
                newPath = currentPath.replace(/^\/[^\/]+/, `/${version}`);
            }
        }

        // Ensure we don't create double slashes
        newPath = newPath.replace(/\/+/g, '/');

        window.location.href = newPath;
    },

    /**
     * Load and populate version selector
     */
    initVersionSelector: function(selectorId) {
        const selector = document.getElementById(selectorId);
        if (!selector) {
            console.warn(`Version selector element '${selectorId}' not found`);
            return;
        }

        const currentVersion = this.getCurrentVersion();
        console.log('Current version detected:', currentVersion);

        // Try to fetch versions.json from multiple locations
        const versionsPaths = [
            '/versions.json',
            './versions.json',
            '../versions.json',
            '/docs/versions.json'
        ];

        this.fetchVersionsFromPaths(versionsPaths)
            .then(versions => {
                if (versions && versions.length > 0) {
                    this.populateSelector(selector, versions, currentVersion);
                } else {
                    this.createFallbackSelector(selector, currentVersion);
                }
            })
            .catch(error => {
                console.log('Mike versions not available:', error);
                this.createFallbackSelector(selector, currentVersion);
            });

        selector.addEventListener('change', (e) => {
            const selectedVersion = e.target.value;
            if (selectedVersion && selectedVersion !== currentVersion) {
                this.switchToVersion(selectedVersion);
            }
        });
    },

    /**
     * Try to fetch versions.json from multiple paths
     */
    fetchVersionsFromPaths: function(paths) {
        return new Promise((resolve, reject) => {
            let attempted = 0;

            const tryNextPath = () => {
                if (attempted >= paths.length) {
                    reject(new Error('No versions.json found in any location'));
                    return;
                }

                const path = paths[attempted];
                attempted++;

                fetch(path)
                    .then(response => {
                        if (!response.ok) {
                            throw new Error(`HTTP ${response.status}`);
                        }
                        return response.json();
                    })
                    .then(versions => {
                        // Validate the versions format
                        if (Array.isArray(versions) && versions.length > 0) {
                            console.log(`Loaded versions from ${path}:`, versions);
                            resolve(versions);
                        } else {
                            throw new Error('Invalid versions format');
                        }
                    })
                    .catch(error => {
                        console.log(`Failed to load from ${path}:`, error.message);
                        tryNextPath();
                    });
            };

            tryNextPath();
        });
    },

    /**
     * Create a fallback selector when versions.json is not available
     */
    createFallbackSelector: function(selector, currentVersion) {
        console.log('Creating fallback version selector');

        selector.innerHTML = '';

        // Create fallback versions
        const fallbackVersions = [
            { version: 'latest', title: 'Latest (Development)', aliases: ['latest'] },
            { version: 'v0.8.4', title: 'v0.8.4 (Stable)', aliases: [] },
            { version: 'v0.8.3', title: 'v0.8.3', aliases: [] }
        ];

        fallbackVersions.forEach(version => {
            const option = document.createElement('option');
            option.value = version.version;
            option.textContent = version.title;

            // Select current version or default to latest
            if (version.version === currentVersion ||
                (currentVersion === 'latest' && version.version === 'latest')) {
                option.selected = true;
            }

            selector.appendChild(option);
        });

        selector.disabled = false;
    },

    /**
     * Populate the version selector with Mike versions
     */
    populateSelector: function(selector, versions, currentVersion) {
        selector.innerHTML = '';

        // Validate and filter versions
        const validVersions = versions.filter(v =>
            v && v.version && typeof v.version === 'string'
        );

        if (validVersions.length === 0) {
            this.createFallbackSelector(selector, currentVersion);
            return;
        }

        // Sort versions: latest first, then semantic versions in descending order
        const sortedVersions = validVersions.sort((a, b) => {
            // Latest version always comes first
            const aIsLatest = a.aliases && a.aliases.includes('latest');
            const bIsLatest = b.aliases && b.aliases.includes('latest');

            if (aIsLatest && !bIsLatest) return -1;
            if (!aIsLatest && bIsLatest) return 1;

            // Handle semantic versions (v1.0.0 format)
            const aMatch = a.version.match(/^v(\d+)\.(\d+)\.(\d+)/);
            const bMatch = b.version.match(/^v(\d+)\.(\d+)\.(\d+)/);

            if (aMatch && bMatch) {
                const [, aMajor, aMinor, aPatch] = aMatch.map(Number);
                const [, bMajor, bMinor, bPatch] = bMatch.map(Number);

                // Compare semantic versions in descending order
                if (aMajor !== bMajor) return bMajor - aMajor;
                if (aMinor !== bMinor) return bMinor - aMinor;
                return bPatch - aPatch;
            }

            // Fallback to string comparison
            return b.version.localeCompare(a.version, undefined, { numeric: true });
        });

        sortedVersions.forEach(version => {
            const option = document.createElement('option');
            option.value = version.version;
            option.textContent = version.title || version.version;

            // Check if this is the current version
            const isCurrentVersion = version.version === currentVersion ||
                (currentVersion === 'latest' && version.aliases && version.aliases.includes('latest'));

            if (isCurrentVersion) {
                option.selected = true;
            }

            selector.appendChild(option);
        });

        selector.disabled = false;
        console.log(`Populated selector with ${sortedVersions.length} versions`);
    },

    /**
     * Initialize version handler when DOM is ready
     */
    init: function() {
        document.addEventListener('DOMContentLoaded', () => {
            // Look for common version selector IDs
            const selectorIds = ['version-selector', 'versions', 'version-dropdown', '__versions'];

            for (const id of selectorIds) {
                const element = document.getElementById(id);
                if (element) {
                    console.log(`Found version selector: ${id}`);
                    this.initVersionSelector(id);
                    break;
                }
            }
        });
    }
};

// Auto-initialize when script loads
window.VersionHandler.init();
