# Rhyme

A portrait iPhone tribute to [rymdkapsel](https://grapefrukt.com/rymdkapsel/) (Grapefrukt). Quiet geometry, white kapsels, two staples (minerals and meals), and a long campaign of short stations.

This is a love letter, not a clone: original room language, original mechanics, and a 42-station campaign.

## Play

Serve the repo and open it on a phone, or in a desktop browser as a tall phone frame:

```bash
python3 -m http.server 4173
```

Then visit `http://localhost:4173`. Add to Home Screen on iPhone for the full portrait shell (notch-safe padding, 44pt controls, thumb-strip tools).

## How it plays

- **Place** tetromino rooms that kiss the station. Blueprints are not walkable until kapsels deliver minerals and finish the floor.
- **Tap a room** to assign the nearest idle kapsel. They haul, build, cook, recruit, and man guns themselves.
- **Gardens** grow. **Extractors** only bite pink mineral fields. Later worlds cook sludge in **kitchens** before it counts as pantry food.
- **Weapons** are mute until staffed. Waves come from the void.
- Worlds introduce **shields & solar flares**, **relics**, **gates**, **ice & heaters**, **cloaked scouts**, **gravity wells**, and **overclocks**.

Progress is saved in the browser (`localStorage`). Each station has a win condition; difficulty ramps across seven worlds.

## Tests

```bash
npm test
```

Headless Node tests cover pathing, assignment, economy, combat, campaign data, and the original mechanics.

## Desktop note

The earlier LÖVE prototype is no longer the playable game. Rhyme is web-first so it can be a one-handed portrait iPhone station.
