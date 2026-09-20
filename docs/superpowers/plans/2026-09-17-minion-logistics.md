# Minion logistics implementation plan

**Goal:** Give minions consequential, visible jobs throughout station operation.

**Architecture:** `economy.lua` owns stockpiles and production. `workers.lua` owns reserved jobs and movement. `grid.lua` owns completed floor paths and blueprints; `main.lua` presents the simulation; `enemies.lua` checks weapon staffing.

**Tech stack:** Lua / LÖVE 11.5, no additional dependencies.

**Spec:** `docs/superpowers/specs/2026-09-17-minion-logistics-design.md`

## Execution

- [x] Add deterministic headless tests in `tests/main.lua` and `tests/conf.lua`. Run with `/Applications/love.app/Contents/MacOS/love tests`. Verify an adjacent path contains its destination before changing path reconstruction.
- [x] Correct grid paths and add blueprint fields and reachable room-edge routing. `Grid.place(type, x, y, instant)` creates a blueprint unless `instant` is true. `Grid.routeToRoom(sx, sy, room)` returns a connected path to usable floor or a construction edge.
- [x] Add room-local production and inventories in `economy.lua`. Expose `reset`, `update(dt)`, `total(resource)`, `available(room, resource)`, `need(room, resource)`, and `add(room, resource, amount)`. Assert kitchens cannot produce without crops and a worker.
- [x] Replace permanent assignments with reserved hauling/action jobs in `workers.lua`. Test mineral and crop movement, construction, cooking, quarters recruitment, full capacity, destroyed destinations, and disconnected jobs. Keep cargo visible until delivery.
- [x] Integrate actual pantry consumption, physical build costs, starter rooms, and staffed weapons in `main.lua` and `enemies.lua`. Add six build buttons and four crew priorities. Draw stockpiles, cargo, progress, and hover status; update `constants.lua` and `conf.lua` for the taller HUD.
- [x] Run the complete simulation suite, inspect the game in LÖVE, review changed files, and document controls in `README.md`.

The repository has no initial commit and its existing game files are untracked. Work in place, preserving those files and leaving changes for user review.

## Verification results

- All 22 headless simulation tests pass.
- Independent review identified three scheduler edge cases; each is fixed and covered by a regression test. Follow-up review found no remaining material issues in those fixes.
- Native LÖVE playtest confirmed initial cargo movement, blueprint delivery counts, completed rooms, priority selection, and readable room/crew status.
- Existing game files remain uncommitted, as they were at the start.
