import "fake-widgets/theme.css";

export { helper } from "fake-helper";

import { nextId } from "./support/ids";

export const widget = { id: () => nextId() };
