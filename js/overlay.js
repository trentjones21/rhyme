export function endOverlaySpec(status, { hasNext } = {}) {
  if (status === "won") {
    return {
      title: "Stable",
      primary: hasNext ? "Next station" : "Campaign complete",
      retry: true,
    };
  }
  return {
    title: "Unstitched",
    primary: "Retry",
    retry: false,
  };
}
