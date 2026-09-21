export function endOverlaySpec(status, { hasNext, worldGate } = {}) {
  if (status === "won") {
    return {
      title: "Stable",
      primary: worldGate ? `Enter ${worldGate}` : hasNext ? "Next station" : "Campaign complete",
      retry: true,
    };
  }
  return {
    title: "Unstitched",
    primary: "Retry",
    retry: false,
  };
}
