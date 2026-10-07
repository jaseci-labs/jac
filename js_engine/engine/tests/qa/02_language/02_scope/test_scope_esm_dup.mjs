// SCP-M-003: invalid module — duplicate name in same scope (parse error)
import { scpMExported } from "./test_scope_esm_export.mjs";
const scpMExported = 1;
