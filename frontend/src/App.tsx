import { Route, Routes } from "react-router";
import { Layout } from "./components/Layout.tsx";
import { AdminPage } from "./pages/AdminPage.tsx";
import { PositionsPage } from "./pages/PositionsPage.tsx";

// The route table: which page is drawn inside the Layout for each URL.
export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<PositionsPage />} />
        <Route path="admin" element={<AdminPage />} />
      </Route>
    </Routes>
  );
}
