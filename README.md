# Rhyme

A portrait iPhone tribute to [rymdkapsel](https://grapefrukt.com/rymdkapsel/) (Grapefrukt). Quiet geometry, white kapsels, two staples (minerals and meals), and a 42-station campaign.

This is a **LÖVE 11.5** game. It is a love letter, not a clone: original room language, original mechanics, and a long campaign of short stations.

## Play

From the repo root:

```bash
love .
```

On a Mac with the official app:

```bash
/Applications/love.app/Contents/MacOS/love .
```

Needs [LÖVE 11.5](https://love2d.org/). The window is portrait (430×932, 9:19.5). On iPhone the same project is the game: touch, notch-safe padding, 44pt controls, wrapping thumb dock. Lock the device in portrait.

Do not open a browser. There is no localhost server in the play path.

## How it plays

- **Place** tetromino rooms that kiss the station. Blueprints are not walkable until kapsels deliver minerals and finish the floor.
- **Tap a room** to assign the nearest idle kapsel. They haul, build, cook, recruit, and man guns themselves.
- **Gardens** grow. **Extractors** only bite pink mineral fields. Later worlds cook sludge in **kitchens** before it counts as pantry food.
- **Weapons** are mute until staffed. Waves come from the void.
- Worlds introduce **shields & solar flares**, **relics**, **gates**, **ice & heaters**, **cloaked scouts**, **gravity wells**, and **overclocks**.

Progress is saved in LÖVE’s save directory. Each station has a win condition; difficulty ramps across seven worlds.

## Tests

```bash
love tests
```

On a Mac:

```bash
/Applications/love.app/Contents/MacOS/love tests
```

Headless LÖVE tests cover pathing, assignment, economy, campaign data, and portrait layout. The suite turns the window, graphics, and audio modules off.

## Leftover web

The merged portrait campaign first shipped as a web app by mistake. That tree now lives in `web/` as the design/content reference (levels, sim, HUD). It is not how you play Rhyme.

## Controls

| Touch / mouse | Action |
| --- | --- |
| Thumb dock | Choose Tap, Hall, Grow, and the rest of the station’s tools |
| Tap empty floor | Place the selected room against the hull |
| Tap a room | Assign the nearest idle kapsel |
| Rotate / Hold / Recall | Shape the bag, park a piece, pull a kapsel home |
| GO | Last Geometry holds time until you tap it |
