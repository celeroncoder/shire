import React from "react";
import ReactDOM from "react-dom/client";
import { App } from "./app";
import "./index.css";

// Debug: catch uncaught errors
window.addEventListener("error", (e) => {
  document.body.innerHTML = `<pre style="color:red;padding:2rem;white-space:pre-wrap;">UNCAUGHT ERROR:\n${e.message}\n${e.filename}:${e.lineno}</pre>`;
});

window.addEventListener("unhandledrejection", (e) => {
  document.body.innerHTML = `<pre style="color:red;padding:2rem;white-space:pre-wrap;">UNHANDLED REJECTION:\n${e.reason}</pre>`;
});

try {
  ReactDOM.createRoot(document.getElementById("root")!).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );
} catch (e) {
  document.body.innerHTML = `<pre style="color:red;padding:2rem;white-space:pre-wrap;">RENDER ERROR:\n${e}</pre>`;
}
