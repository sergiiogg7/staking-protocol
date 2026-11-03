import { useState } from "react";
import { useAccount } from "wagmi";
import { ActivityTable } from "../components/ActivityTable.tsx";
import { useActivity } from "../hooks/useActivity.ts";
import type { ActivityScope } from "../hooks/useActivity.ts";

export function ActivityPage() {
  const { isConnected } = useAccount();
  const [scope, setScope] = useState<ActivityScope>("all");
  const { data: items, isPending, error } = useActivity(scope);

  return (
    <section>
      <h2>Protocol activity</h2>
      {/* aria-pressed tells assistive technology which of the two buttons is the active one. */}
      <div className="actions">
        <button className={scope === "all" ? undefined : "secondary"} aria-pressed={scope === "all"} onClick={() => setScope("all")}>
          All activity
        </button>
        <button className={scope === "mine" ? undefined : "secondary"} aria-pressed={scope === "mine"} onClick={() => setScope("mine")}>
          My activity
        </button>
      </div>

      <Content scope={scope} isConnected={isConnected} isPending={isPending} error={error} items={items} />
    </section>
  );
}

interface ContentProps {
  scope: ActivityScope;
  isConnected: boolean;
  isPending: boolean;
  error: Error | null;
  items: Parameters<typeof ActivityTable>[0]["items"] | undefined;
}

// The same order as the other lists: a disabled query also reports isPending, so check the wallet first.
function Content({ scope, isConnected, isPending, error, items }: ContentProps) {
  if (scope === "mine" && !isConnected) return <p>Connect your wallet to see your own activity.</p>;
  if (isPending) return <p>Loading the activity…</p>;
  if (error) return <p className="error">Could not load the activity: {error.message}</p>;
  return <ActivityTable items={items ?? []} />;
}
