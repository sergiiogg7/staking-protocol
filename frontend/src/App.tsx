import { ConnectButton } from "./components/ConnectButton.tsx";
import { DepositPanel } from "./components/DepositPanel.tsx";
import { PositionsList } from "./components/PositionsList.tsx";
import { ProtocolStats } from "./components/ProtocolStats.tsx";

export default function App() {
  return (
    <main>
      <header>
        <h1>STK Staking</h1>
        <ConnectButton />
      </header>
      <ProtocolStats />
      <h2>My positions</h2>
      <DepositPanel />
      <PositionsList />
    </main>
  );
}
