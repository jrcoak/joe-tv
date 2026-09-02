# RALLY — Live TV, alive.

RALLY is a remote-first television design concept for live channels and major-league sports. It combines a 50-channel guide with an event-led sports experience spanning NFL, MLB, NBA, and NHL references.

## Start here

1. Read [`RALLY-DESIGN-WRITEUP.md`](design/RALLY-DESIGN-WRITEUP.md) for the product thesis, interaction model, visual system, and screen-by-screen rationale.
2. Open [`RALLY-Design-Concept.pdf`](RALLY-Design-Concept.pdf) for the presentation-ready case study.
3. Browse [`screenshots/`](screenshots/) for the full-resolution 1920 × 1080 concept screens.
4. Run [`prototype/`](prototype/) to explore the remote-first interaction model.

Live concept: <https://rally-tv.josephrcoakley.chatgpt.site/>

## What is included

- A presentation PDF and editable Markdown design writeup
- Nine curated concept images: cover plus eight core product states
- The complete interactive prototype source, without dependencies or deployment credentials
- A remote-navigation map
- Research and visual-asset source notes
- A manifest describing every deliverable

## Run the prototype locally

Requirements: Node.js 22.13 or newer and pnpm.

```bash
cd prototype
pnpm install
pnpm dev
```

Open the local address printed by the development server.

## Remote / keyboard controls

| Input | Behavior |
| --- | --- |
| Arrow keys | Move spatial focus |
| Enter / OK | Select the focused control |
| Escape / Back | Dismiss one layer and restore context |
| G | Open the live TV guide |
| Space | Play or pause while watching |
| Page Up / Page Down | Move through the guide eight channels at a time |

## Important note

RALLY is an independent, non-commercial design concept. Static game data and references to leagues, teams, channels, and broadcasters are included only to make the scenario realistic. Their names and marks belong to their respective owners. The prototype uses remotely hosted editorial imagery; see [`assets/ASSET-SOURCES.md`](assets/ASSET-SOURCES.md).

