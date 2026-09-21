export function shouldShowInstallHint({ ios, standalone, dismissed }) {
  if (standalone || dismissed) return false;
  return ios === true;
}
