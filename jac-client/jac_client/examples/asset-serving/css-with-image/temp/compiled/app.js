import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { useState, useEffect } from "react";
import "./styles.css";
function app() {
  let [count, setCount] = useState(0);
  useEffect(() => {
    console.log("Count: ", count);
  }, [count]);
  return __jacJsx("div", {"style": {padding: "20px", textAlign: "center", fontFamily: "Arial, sans-serif"}}, [__jacJsx("h1", {}, ["🍔 Burger Counter App"]), __jacJsx("img", {"src": "/static/assets/burger.png", "alt": "Delicious Burger", "style": {width: "200px", height: "auto", margin: "20px 0", borderRadius: "10px", boxShadow: "0 4px 8px rgba(0,0,0,0.2)"}}, []), __jacJsx("p", {"style": {fontSize: "18px", margin: "20px 0"}}, ["You've clicked the burger", __jacJsx("strong", {}, [count]), "times!"]), __jacJsx("button", {"onClick": e => {
    setCount(count + 1);
  }, "style": {padding: "10px 20px", fontSize: "16px", backgroundColor: "#ff6b35", color: "white", border: "none", borderRadius: "5px", cursor: "pointer", boxShadow: "0 2px 4px rgba(0,0,0,0.2)"}}, ["Click the Burger! 🍔"]), __jacJsx("h2", {"style": {marginTop: "40px", marginBottom: "20px"}}, ["CSS Asset Examples"]), __jacJsx("div", {"className": "container"}, [__jacJsx("h3", {"style": {color: "white", textShadow: "2px 2px 4px rgba(0,0,0,0.5)"}}, ["Background Image Example"]), __jacJsx("p", {"style": {color: "white", textShadow: "2px 2px 4px rgba(0,0,0,0.5)"}}, ["This container uses the burger image as a background via CSS"])]), __jacJsx("div", {"className": "card"}, [__jacJsx("h3", {}, ["Image in Card"]), __jacJsx("img", {"src": "/static/assets/burger.png", "alt": "Burger in Card", "className": "burgerImage"}, []), __jacJsx("p", {"style": {marginTop: "15px", color: "#666"}}, ["This image is displayed within a styled card using CSS classes"])])]);
}
export { app };
