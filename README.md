<p align="center">
  <img src="assets/logo.svg" width="128" height="128" alt="Musor Drop logo">
</p>

<h1 align="center">Musor Drop</h1>

<p align="center">
  A Raycast extension that turns your Mac into a pop-up ad nightmare.
</p>

## Commands

| Command | What it does |
| --- | --- |
| **Musor Drop** | Plays the MUSOR DROP ad full-width on top of everything, at full volume, then vanishes. |
| **Musor Swarm** | Spawns a swarm of small ads at random spots on the screen. They pop up quickly one after another and each starts playing the moment it appears. |

Ads float above every window and every Space, ignore the mouse, and close themselves when the video ends.

**Musor Swarm** has a `Number of Ads` preference (default `20`, max `60`).

## Requirements

- macOS 13+
- [Raycast](https://raycast.com)
- Node.js 20+
- Xcode Command Line Tools (`xcode-select --install`) — the player is a small Swift binary compiled from source

## Install

```bash
git clone https://github.com/umbra2728/raycast-musor-drop.git
cd raycast-musor-drop
npm install
npm run dev
```

`npm run dev` compiles the player and imports the extension into Raycast. After that the commands stay available even when the dev server is stopped.

## How it works

Raycast can't draw over other apps, so the commands launch `assets/musor-drop-player` — a tiny AppKit/AVFoundation app built from [`player/main.swift`](player/main.swift):

```bash
musor-drop-player <video>                  # one full-width ad
musor-drop-player --swarm <count> <video>  # a swarm of small ads
```

It opens borderless windows at screen-saver level on the screen under the mouse cursor, plays the video, and quits once every ad has finished.

## Scripts

| Script | Description |
| --- | --- |
| `npm run dev` | Build the player and start Raycast development mode |
| `npm run build` | Build the player and the extension into `dist` |
| `npm run build:player` | Compile only the Swift player |
| `npm run typecheck` | Type-check the TypeScript sources |

## License

[MIT](LICENSE)
