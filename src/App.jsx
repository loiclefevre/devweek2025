import { Route /* Link */ } from "wouter";
import "./styles.css";

import WithReact from "./WithReact";

export default function App() {
  return (
    <div>
      <Route path="/" component={WithReact} />
    </div>
  );
}
