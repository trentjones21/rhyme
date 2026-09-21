local M = {}

function M.endOverlaySpec(status, opts)
  opts = opts or {}
  if status == "won" then
    local primary
    if opts.worldGate then
      primary = "Enter " .. opts.worldGate
    elseif opts.hasNext then
      primary = "Next station"
    else
      primary = "Campaign complete"
    end
    return { title = "Stable", primary = primary, retry = true }
  end
  return { title = "Unstitched", primary = "Retry", retry = false }
end

return M
