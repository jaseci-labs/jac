export const state = {pending: [], dropped: [], env: null};
let next = 0;
export function bind_na_host(nativeExport, host) {
  state.env = host;
}
export function __na_bind() {
  return {
    init: () => new Promise(resolve => {
      const game = ++next;
      state.pending.push(() => resolve(game));
    }),
    frame: async () => {
      if (state.failFrame) throw new Error('frame failure');
      return false;
    },
    shutdown: async game => { state.dropped.push(game); },
    get_score: async () => 12,
    get_hp: async () => 95,
    get_deaths: async () => 3,
  };
}
