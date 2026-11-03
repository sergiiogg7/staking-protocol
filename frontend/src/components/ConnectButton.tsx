import { useAccount, useConfig, useConnect, useDisconnect, useSwitchChain } from "wagmi";

function shorten(address: string) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function ConnectButton() {
  const { address, chain, isConnected } = useAccount();
  const { connect, connectors, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();
  const supportedChain = useConfig().chains[0];

  if (!isConnected) {
    // `injected()` reports the real wallet name (e.g. "MetaMask"), or a generic one when none is installed.
    const connector = connectors[0];
    return (
      <div className="connect">
        <button disabled={!connector || isPending} onClick={() => connector && connect({ connector })}>
          {isPending ? "Connecting…" : "Connect wallet"}
        </button>
        {error && <p className="error">{error.message}</p>}
      </div>
    );
  }

  // `chain` is undefined when the wallet is on a network this app does not support.
  if (!chain) {
    return (
      <div className="connect">
        <button disabled={isSwitching} onClick={() => switchChain({ chainId: supportedChain.id })}>
          {isSwitching ? "Switching…" : `Switch to ${supportedChain.name}`}
        </button>
        <button className="secondary" onClick={() => disconnect()}>
          Disconnect
        </button>
      </div>
    );
  }

  return (
    <div className="connect">
      <span title={address}>
        {shorten(address ?? "")} · {chain.name}
      </span>
      <button className="secondary" onClick={() => disconnect()}>
        Disconnect
      </button>
    </div>
  );
}
