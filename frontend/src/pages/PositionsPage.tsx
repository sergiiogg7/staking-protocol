import { DepositPanel } from "../components/DepositPanel.tsx";
import { PositionsList } from "../components/PositionsList.tsx";
import { ProtocolStats } from "../components/ProtocolStats.tsx";

export function PositionsPage() {
  return (
    <>
      <ProtocolStats />
      <h2>My positions</h2>
      <DepositPanel />
      <PositionsList />
    </>
  );
}
