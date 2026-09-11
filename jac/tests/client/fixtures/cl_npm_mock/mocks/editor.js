const priorities = [];

export const editor = {
  showQuickPick: async (items) => items[items.length - 1],

  createStatusBarItem: (align, priority) => {
    priorities.push(priority);
    return { text: "", show() {}, dispose() {} };
  },
};

export function recordedPriorities() {
  return priorities;
}
