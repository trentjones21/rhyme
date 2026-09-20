# Minion logistics

Make the station run through visible work: workers collect individual resource blocks, carry them along connected floors, deliver them, and perform construction, cooking, recruitment, and defense jobs.

## Simulation

Keep LÖVE 11.5 and the existing grid, drawing style, combat, and controls. Add a room-local economy module. Gardens grow crops and extractors produce minerals into limited local stockpiles. Workers carry crops to kitchens, cook meals, and deliver meals to the core pantry or quarters. Core meals sustain the crew. Each completed quarters can recruit two workers after workers deliver and prepare meals there.

Placement creates a blueprint. Workers fetch minerals from actual stockpiles, deliver the required cost to a reachable edge of the blueprint, and build it. Unfinished rooms cannot produce, fire, or provide a walking shortcut. Queued rooms can touch other blueprints; they wait until connected construction makes them reachable.

Workers reserve both pickup stock and destination capacity. Jobs release reservations after cancellation, starvation, demolition, or route loss. Carried resources are retained for a reachable return delivery when the original destination disappears. Paths include every orthogonal step and never cross missing floor tiles.

Weapons rooms require a defending worker. Incoming waves automatically raise defense priority; surviving workers return to logistics afterward. Balanced, construction, food, and defense priorities let the player influence the scheduler without ordering individual workers.

## Opening and feedback

Start with five workers, a small garden, kitchen, extractor, and weapons room. Seed crops/minerals and queue a quarters blueprint so useful work is visible immediately. Draw resource stacks, distinct cargo colors, work progress, blueprint material counts, room hover explanations, and crew activity counts. Retain the existing 880px width; add space below the grid for six room buttons and priorities.

## Verification

Use a headless LÖVE test harness with deterministic seeds. Test adjacent/corner routes, physical delivery before credit, full production chains, construction and unreachable blueprints, duplicate reservations, cancellation while carrying, disconnected routes, recruitment, and staffed weapons. Exercise the running game visually and verify pause, restart, placement, priorities, and readable status.
