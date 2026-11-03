import { ConnectButton } from "./components/ConnectButton.tsx";
import { ProtocolStats } from "./components/ProtocolStats.tsx";

export default function App() {
  return (
    <main>
      <header>
        <h1>STK Staking</h1>
        <ConnectButton />
      </header>
      <ProtocolStats />
    </main>
  );
}
