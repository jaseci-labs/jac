import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useState, useEffect } from "react";
function app() {
  let [count, setCount] = useState(0);
  useEffect(() => {
    console.log("Count: ", count);
  }, [count]);
  return __jacJsx("div", {}, [__jacJsx("h1", {}, ["Hello, World!"]), __jacJsx("p", {}, ["Count: ", count]), __jacJsx("button", {"onClick": e => {
    setCount(count + 1);
  }}, ["Increment"])]);
}
export { app };
