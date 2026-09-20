# Rhyme

A small LÖVE 11.5 station-building game with a physical worker economy inspired by Rymdkapsel.

Run `love .` (on this Mac: `/Applications/love.app/Contents/MacOS/love .`).

## What the crew does

- Gardens grow green crops. Workers carry them to kitchens and cook each crop into three yellow meals.
- Meals travel to the core pantry to feed the crew, or to quarters. Three meals and preparation recruit a minion; each quarters supports two recruits.
- Extractors produce blue mineral blocks. Workers haul individual blocks to storage and construction sites.
- Placed rooms start as blueprints. Workers deliver their mineral cost and then construct them. Unfinished floor is impassable, so queued corridors are built outward in order.
- Weapons require a defending worker. Incoming waves automatically call crew to available weapons, and defenders resume normal work after the attack.

Five workers and a compact supply chain are ready at the start, with a quarters blueprint waiting for materials. Expand the station to create more work. When storage is full and all tasks are done, workers wait until a useful job opens up.

## Controls

| Input | Action |
| --- | --- |
| 1–6 or room buttons | Choose corridor, garden, extractor, weapons, kitchen, or quarters |
| Left-click empty connected space | Queue construction; payment happens through deliveries |
| Right-click a room | Salvage it; removes its floor too |
| Crew buttons or Tab | Favor balanced work, construction, food service, or defense |
| Hover a worker or room | Inspect its task, route, or purpose |
| P | Pause/resume |
| R | Restart |
| Escape | Quit |

The pantry counter shows **delivered** meals; food waiting in a kitchen or being carried cannot feed the station yet. Short, connected routes matter. Supply food and minerals, build quarters to grow, and spread staffed weapons around the station before waves arrive. Priorities influence task selection; loaded workers finish their deliveries before changing duties.

Development shortcuts: M adds minerals, F adds pantry meals, and N triggers the next wave.

## Tests

Run `love tests` (on this Mac: `/Applications/love.app/Contents/MacOS/love tests`). The headless suite exercises real simulation code, including resource transfers, reservations, construction order, broken paths, cooking, recruitment, staffing, pause/restart, and extended wave/priority simulation.
