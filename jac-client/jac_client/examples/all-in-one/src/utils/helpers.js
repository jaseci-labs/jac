// JavaScript utility functions
// Demonstrates: importing JavaScript files in JAC

/**
 * Generate a unique ID
 * @returns {string} Unique identifier
 */
export function generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

/**
 * Calculate percentage
 * @param {number} part - The part value
 * @param {number} total - The total value
 * @returns {string} Percentage as string with one decimal
 */
export function calculatePercentage(part, total) {
    if (total === 0) return "0";
    return ((part / total) * 100).toFixed(1);
}

/**
 * Group array items by a key
 * @param {Array} array - Array to group
 * @param {string} key - Key to group by
 * @returns {Object} Grouped object
 */
export function groupBy(array, key) {
    return array.reduce((result, item) => {
        const groupKey = item[key];
        if (!result[groupKey]) {
            result[groupKey] = [];
        }
        result[groupKey].push(item);
        return result;
    }, {});
}

/**
 * Sum values in array by key
 * @param {Array} array - Array of objects
 * @param {string} key - Key to sum
 * @returns {number} Sum of values
 */
export function sumBy(array, key) {
    return array.reduce((sum, item) => sum + (item[key] || 0), 0);
}

/**
 * Sort array by key
 * @param {Array} array - Array to sort
 * @param {string} key - Key to sort by
 * @param {boolean} ascending - Sort direction
 * @returns {Array} Sorted array
 */
export function sortBy(array, key, ascending = true) {
    return [...array].sort((a, b) => {
        if (ascending) {
            return a[key] > b[key] ? 1 : -1;
        }
        return a[key] < b[key] ? 1 : -1;
    });
}
