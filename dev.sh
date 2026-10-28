#!/usr/bin/env bash
# Local dev environment: Anvil + contract deploy + seed data.
# Usage: bash dev.sh
set -e

ANVIL_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
RPC="http://127.0.0.1:8545"

echo ""
echo "=== STK Staking — Local Dev ==="
echo ""

# Kill any existing Anvil process
if pkill -f "anvil" 2>/dev/null; then
  echo "Stopped previous Anvil instance."
  sleep 1
fi

# Start Anvil with 2-second block time
echo "Starting Anvil..."
anvil --block-time 2 --silent &
ANVIL_PID=$!

# Wait until Anvil accepts connections
until cast chain-id --rpc-url "$RPC" &>/dev/null; do
  sleep 0.5
done
echo "Anvil ready (PID $ANVIL_PID, chain 31337)"
echo ""

# Deploy all contracts + seed data
echo "Deploying contracts..."
forge script script/LocalDeploy.s.sol \
  --rpc-url "$RPC" \
  --private-key "$ANVIL_PK" \
  --broadcast \
  --quiet
echo ""

echo "=== Done! ==="
echo ""
echo "Each Anvil account now has 100 STK and 10000 ETH."
echo "Recommended test account:"
echo "  Address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
echo "  Key:     0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
echo ""
echo "Next steps:"
echo "  1. Add Anvil to MetaMask (RPC: http://127.0.0.1:8545, ChainID: 31337)"
echo "  2. Import the account above"
echo "  3. Start the frontend (see PLAN.md, phase 3)"
echo ""
echo "Anvil is running. Press Ctrl+C to stop."
echo ""

wait $ANVIL_PID
