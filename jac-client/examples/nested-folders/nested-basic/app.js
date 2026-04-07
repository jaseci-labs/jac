import { CustomButton } from "./components/button.js";
function RelativeImport() {
  return __jacJsx("div", {}, [__jacJsx(CustomButton, {}, [])]);
}
function app() {
  return __jacJsx(RelativeImport, {}, []);
}
