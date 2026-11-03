import { NavLink, Outlet } from "react-router";
import { ConnectButton } from "./ConnectButton.tsx";

// The frame shared by every page: title, wallet button and navigation. <Outlet /> is where the page of the
// current route is drawn.
export function Layout() {
  return (
    <main>
      <header>
        <h1>STK Staking</h1>
        <ConnectButton />
      </header>
      <nav>
        {/* NavLink adds the "active" class to the link of the current page; `end` stops "/" matching every route. */}
        <NavLink to="/" end>
          Positions
        </NavLink>
        <NavLink to="/admin">Admin</NavLink>
      </nav>
      <Outlet />
    </main>
  );
}
