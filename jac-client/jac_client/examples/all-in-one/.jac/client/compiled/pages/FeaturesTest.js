import {__jacJsx, __jacSpawn} from "@jac-client/utils";
import { Link, useNavigate } from "@jac-client/utils";
import { useState, useEffect } from "react";
import { PieChart } from "../components/PieChart.js";
import { generateId, calculatePercentage, sumBy } from "../utils/helpers.js";
import { formatCurrency } from "../utils/formatters.js";
export function TestButton(props) {
  const {text, onClick, variant} = props;
  let bg_color = variant === "primary" ? "#3b82f6" : "#6b7280";
  let hover_color = variant === "primary" ? "#2563eb" : "#4b5563";
  return __jacJsx("button", {"onClick": onClick, "style": {"padding": "10px 20px", "backgroundColor": bg_color, "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer", "fontSize": "14px", "fontWeight": "600", "transition": "all 0.2s"}, "onMouseOver": e => {
    e.target.style.backgroundColor = hover_color;
  }, "onMouseOut": e => {
    e.target.style.backgroundColor = bg_color;
  }}, [text]);
}
export function TestCard(props) {
  const {title, children, color} = props;
  return __jacJsx("div", {"style": {"backgroundColor": "white", "border": "1px solid #e5e7eb", "borderRadius": "8px", "padding": "20px", "marginBottom": "20px", "boxShadow": "0 1px 3px rgba(0,0,0,0.1)"}}, [__jacJsx("div", {"style": {"backgroundColor": color, "padding": "10px", "borderRadius": "6px", "marginBottom": "15px"}}, [__jacJsx("h3", {"style": {"margin": "0", "fontSize": "18px", "fontWeight": "600", "color": "#1f2937"}}, [title])]), __jacJsx("div", {}, [children])]);
}
export function ResultDisplay(props) {
  const {data, label} = props;
  if (!data) {
    return __jacJsx("div", {"style": {"color": "#9ca3af", "fontStyle": "italic"}}, ["No data to display"]);
  }
  return __jacJsx("div", {"style": {"backgroundColor": "#f9fafb", "padding": "15px", "borderRadius": "6px", "border": "1px solid #e5e7eb"}}, [__jacJsx("strong", {"style": {"color": "#374151"}}, [label, ":"]), __jacJsx("pre", {"style": {"marginTop": "10px", "padding": "10px", "backgroundColor": "#1f2937", "color": "#10b981", "borderRadius": "4px", "overflow": "auto", "fontSize": "12px", "fontFamily": "monospace"}}, [JSON.stringify(data, null, 2)])]);
}
export function FeaturesTest() {
  let navigate = useNavigate();
  let [testMessage, setTestMessage] = useState("");
  let [testData, setTestData] = useState([]);
  let [stringInput, setStringInput] = useState("Hello JAC World!");
  let [stringResult, setStringResult] = useState(null);
  let [numberList, setNumberList] = useState("1,2,3,4,5");
  let [listResult, setListResult] = useState(null);
  let [complexResult, setComplexResult] = useState(null);
  let [loading, setLoading] = useState(false);
  useEffect(() => {
    async function loadData() {
      try {
        let result = await __jacSpawn("read_test_data", "", {});
        setTestData(result.reports[0] ? result.reports : []);
      } catch (e) {
        console.log("Error loading data:", e);
      }
    }
    loadData();
  }, []);
  async function handleCreate() {
    if (!testMessage.trim()) {
      alert("Please enter a message");
      return;
    }
    setLoading(true);
    try {
      let response = await __jacSpawn("create_test_data", "", {"message": testMessage.trim()});
      let new_item = response.reports[0][0];
      setTestData(testData.concat([new_item]));
      setTestMessage("");
      alert("Data created successfully!");
    } catch (e) {
      console.error("Error creating data:", e);
      alert("Error creating data: " + e.toString());
    }
    setLoading(false);
  }
  async function handleUpdate(item_id) {
    let new_msg = prompt("Enter new message:");
    if (!new_msg) {
      return;
    }
    setLoading(true);
    try {
      await __jacSpawn("update_test_data", item_id, {"new_message": new_msg});
      let result = await __jacSpawn("read_test_data", "", {});
      setTestData(result.reports[0] ? result.reports : []);
      alert("Data updated successfully!");
    } catch (e) {
      console.error("Error updating data:", e);
      alert("Error updating data: " + e.toString());
    }
    setLoading(false);
  }
  async function handleDelete(item_id) {
    if (!confirm("Are you sure you want to delete this item?")) {
      return;
    }
    setLoading(true);
    try {
      await __jacSpawn("delete_test_data", item_id, {});
      setTestData(testData.filter(item => {
        return item._jac_id !== item_id;
      }));
      alert("Data deleted successfully!");
    } catch (e) {
      console.error("Error deleting data:", e);
      alert("Error deleting data: " + e.toString());
    }
    setLoading(false);
  }
  async function handleStringTest() {
    setLoading(true);
    try {
      let response = await __jacSpawn("test_string_methods", "", {"input_text": stringInput});
      let result = response.reports[0];
      setStringResult(result);
    } catch (e) {
      console.error("Error testing strings:", e);
      alert("Error testing strings: " + e.toString());
    }
    setLoading(false);
  }
  async function handleListTest() {
    setLoading(true);
    try {
      let numbers = numberList.split(",").map(x => {
        return parseInt(x.trim());
      }).filter(x => {
        return !isNaN(x);
      });
      let response = await __jacSpawn("test_list_operations", "", {"numbers": numbers});
      let result = response.reports[0];
      setListResult(result);
    } catch (e) {
      console.error("Error testing lists:", e);
      alert("Error testing lists: " + e.toString());
    }
    setLoading(false);
  }
  async function handleComplexTest() {
    setLoading(true);
    try {
      let sample_items = [{"id": generateId(), "name": "apple", "value": 10}, {"id": generateId(), "name": "banana", "value": 20}, {"id": generateId(), "name": "cherry", "value": 30}];
      let response = await __jacSpawn("process_complex_data", "", {"items": sample_items});
      let result = response.reports[0];
      setComplexResult(result);
    } catch (e) {
      console.error("Error processing complex data:", e);
      alert("Error processing complex data: " + e.toString());
    }
    setLoading(false);
  }
  let demo_text = "JAC Language Features";
  let string_demos = {"Original": demo_text, "Uppercase": demo_text.toUpperCase(), "Lowercase": demo_text.toLowerCase(), "Length": demo_text.length.toString(), "Split by space": demo_text.split(" ").join(", ")};
  let chart_data = [{"name": "Walker Tests", "value": 5}, {"name": "String Methods", "value": 8}, {"name": "List Operations", "value": 7}, {"name": "Components", "value": 4}];
  let total_tests = sumBy(chart_data, "value");
  return __jacJsx("div", {"style": {"maxWidth": "1200px", "margin": "0 auto", "padding": "20px", "fontFamily": "system-ui, -apple-system, sans-serif"}}, [__jacJsx("div", {"style": {"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "30px"}}, [__jacJsx("h1", {"style": {"color": "#1f2937", "margin": "0"}}, ["JAC Features Test Suite"]), __jacJsx(Link, {"to": "/"}, [__jacJsx(TestButton, {"text": "← Back Home", "onClick": () => {}, "variant": "secondary"}, [])])]), loading && __jacJsx("div", {"style": {"position": "fixed", "top": "20px", "right": "20px", "backgroundColor": "#3b82f6", "color": "white", "padding": "10px 20px", "borderRadius": "6px", "boxShadow": "0 4px 6px rgba(0,0,0,0.2)", "zIndex": "1000"}}, ["Processing..."]), __jacJsx(TestCard, {"title": "1. Walker CRUD Operations (Spawn from CL)", "color": "#dbeafe"}, [__jacJsx("div", {"style": {"marginBottom": "15px"}}, [__jacJsx("p", {"style": {"color": "#4b5563", "marginBottom": "10px"}}, ["Test creating, reading, updating, and deleting data using walkers spawned from client code."]), __jacJsx("div", {"style": {"display": "flex", "gap": "10px", "marginBottom": "15px"}}, [__jacJsx("input", {"type": "text", "value": testMessage, "onChange": e => {
    setTestMessage(e.target.value);
  }, "placeholder": "Enter test message...", "style": {"flex": "1", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}, []), __jacJsx(TestButton, {"text": "Create", "onClick": () => {
    handleCreate();
  }, "variant": "primary"}, [])]), __jacJsx("div", {"style": {"marginTop": "20px"}}, [__jacJsx("strong", {"style": {"color": "#374151"}}, ["Stored Data (", testData.length, " items):"]), testData.length === 0 && __jacJsx("p", {"style": {"color": "#9ca3af", "fontStyle": "italic"}}, ["No data yet. Create some!"]), testData.map(item => {
    return __jacJsx("div", {"key": item._jac_id, "style": {"backgroundColor": "#f9fafb", "padding": "12px", "borderRadius": "6px", "marginTop": "8px", "display": "flex", "justifyContent": "space-between", "alignItems": "center"}}, [__jacJsx("div", {}, [__jacJsx("div", {"style": {"fontWeight": "600", "color": "#1f2937"}}, [item.message]), __jacJsx("div", {"style": {"fontSize": "12px", "color": "#6b7280"}}, ["Count: ", item.count, " | Created: ", item.created_at])]), __jacJsx("div", {"style": {"display": "flex", "gap": "8px"}}, [__jacJsx(TestButton, {"text": "Edit", "onClick": () => {
      handleUpdate(item._jac_id);
    }, "variant": "secondary"}, []), __jacJsx(TestButton, {"text": "Delete", "onClick": () => {
      handleDelete(item._jac_id);
    }, "variant": "secondary"}, [])])]);
  })])])]), __jacJsx(TestCard, {"title": "2. String Methods (Client & Walker)", "color": "#fce7f3"}, [__jacJsx("div", {}, [__jacJsx("p", {"style": {"color": "#4b5563", "marginBottom": "10px"}}, ["Client-side string manipulation and walker-based string processing."]), __jacJsx("div", {"style": {"marginBottom": "20px"}}, [__jacJsx("strong", {"style": {"color": "#374151"}}, ["Client-side String Demo:"]), __jacJsx("div", {"style": {"backgroundColor": "#fef3c7", "padding": "10px", "borderRadius": "6px", "marginTop": "8px"}}, [Object.keys(string_demos).map(key => {
    return __jacJsx("div", {"key": key, "style": {"marginBottom": "5px"}}, [__jacJsx("span", {"style": {"fontWeight": "600"}}, [key, ":"]), " ", string_demos[key]]);
  })])]), __jacJsx("div", {}, [__jacJsx("strong", {"style": {"color": "#374151"}}, ["Walker String Processing:"]), __jacJsx("div", {"style": {"display": "flex", "gap": "10px", "marginTop": "10px"}}, [__jacJsx("input", {"type": "text", "value": stringInput, "onChange": e => {
    setStringInput(e.target.value);
  }, "style": {"flex": "1", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}, []), __jacJsx(TestButton, {"text": "Process with Walker", "onClick": () => {
    handleStringTest();
  }, "variant": "primary"}, [])]), stringResult && __jacJsx(ResultDisplay, {"data": stringResult, "label": "Walker Result"}, [])])])]), __jacJsx(TestCard, {"title": "3. List/Array Operations", "color": "#ddd6fe"}, [__jacJsx("div", {}, [__jacJsx("p", {"style": {"color": "#4b5563", "marginBottom": "10px"}}, ["Process arrays/lists using walker operations."]), __jacJsx("div", {"style": {"display": "flex", "gap": "10px", "marginTop": "10px"}}, [__jacJsx("input", {"type": "text", "value": numberList, "onChange": e => {
    setNumberList(e.target.value);
  }, "placeholder": "Enter numbers (comma-separated)", "style": {"flex": "1", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}, []), __jacJsx(TestButton, {"text": "Process List", "onClick": () => {
    handleListTest();
  }, "variant": "primary"}, [])]), listResult && __jacJsx(ResultDisplay, {"data": listResult, "label": "List Operations Result"}, [])])]), __jacJsx(TestCard, {"title": "4. TypeScript Component (PieChart.tsx)", "color": "#ccfbf1"}, [__jacJsx("div", {}, [__jacJsx("p", {"style": {"color": "#4b5563", "marginBottom": "10px"}}, ["Imported TypeScript React component with data from JAC."]), __jacJsx(PieChart, {"data": chart_data, "title": "Feature Test Distribution"}, []), __jacJsx("p", {"style": {"marginTop": "10px", "color": "#6b7280", "fontSize": "14px"}}, ["Total tests: ", total_tests, " (calculated using JS helper: sumBy)"])])]), __jacJsx(TestCard, {"title": "5. Import Demonstrations", "color": "#fed7aa"}, [__jacJsx("div", {}, [__jacJsx("p", {"style": {"color": "#4b5563", "marginBottom": "15px"}}, ["This page demonstrates various import types:"]), __jacJsx("ul", {"style": {"color": "#374151", "lineHeight": "1.8"}}, [__jacJsx("li", {}, [__jacJsx("strong", {}, ["JAC-Client Utils:"]), " Router components (Link, useNavigate)"]), __jacJsx("li", {}, [__jacJsx("strong", {}, ["React:"]), " Hooks (useState, useEffect)"]), __jacJsx("li", {}, [__jacJsx("strong", {}, ["TypeScript:"]), " PieChart component from .tsx file"]), __jacJsx("li", {}, [__jacJsx("strong", {}, ["JavaScript:"]), " Helper functions from .js file (generateId, sumBy)"]), __jacJsx("li", {}, [__jacJsx("strong", {}, ["JAC Files:"]), " formatCurrency from utils/formatters.jac"])]), __jacJsx("div", {"style": {"backgroundColor": "#f0fdf4", "padding": "15px", "borderRadius": "6px", "marginTop": "15px"}}, [__jacJsx("strong", {"style": {"color": "#065f46"}}, ["Examples:"]), __jacJsx("div", {"style": {"marginTop": "8px", "fontSize": "14px", "color": "#047857"}}, [__jacJsx("div", {}, ["Generated ID: ", generateId()]), __jacJsx("div", {}, ["Formatted Currency: ", formatCurrency(1234.56)]), __jacJsx("div", {}, ["Percentage Calc: ", calculatePercentage(75, 100), "%"])])])])]), __jacJsx(TestCard, {"title": "6. Complex Data Processing", "color": "#e0e7ff"}, [__jacJsx("div", {}, [__jacJsx("p", {"style": {"color": "#4b5563", "marginBottom": "10px"}}, ["Process complex nested data structures with walkers."]), __jacJsx(TestButton, {"text": "Process Sample Data", "onClick": () => {
    handleComplexTest();
  }, "variant": "primary"}, []), complexResult && __jacJsx(ResultDisplay, {"data": complexResult, "label": "Complex Processing Result"}, [])])]), __jacJsx("div", {"style": {"marginTop": "30px", "padding": "20px", "backgroundColor": "#f9fafb", "borderRadius": "8px", "textAlign": "center", "color": "#6b7280"}}, [__jacJsx("p", {"style": {"margin": "0"}}, ["✅ All features tested: Props, Exports, CL Files, TypeScript, JavaScript, JAC Imports, String Methods, Walker Spawning"])])]);
}
