import {__jacJsx, __jacSpawn} from "@jac-client/utils";
export function formatCurrency(amount) {
  let formatted = amount.toFixed(2);
  return "$" + formatted;
}
export function formatDate(dateStr) {
  let date = Reflect.construct(Date, [dateStr]);
  return date.toLocaleDateString("en-US", {"month": "short", "day": "numeric", "year": "numeric"});
}
export function capitalize(text) {
  if (text.length === 0) {
    return text;
  }
  return text[0].toUpperCase() + text.slice(1).toLowerCase();
}
export function truncate(text, maxLength) {
  if (text.length <= maxLength) {
    return text;
  }
  return text.slice(0, maxLength) + "...";
}
export function formatCompact(num) {
  if (num >= 1000000) {
    let divided = num / 1000000;
    let rounded = Math.round(divided * 10) / 10;
    return rounded.toString().concat("M");
  }
  if (num >= 1000) {
    let divided = num / 1000;
    let rounded = Math.round(divided * 10) / 10;
    return rounded.toString().concat("K");
  }
  return Math.round(num).toString();
}
