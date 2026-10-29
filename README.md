# APEX Age of Sail

Godot 4.7.2 sailing project. The current focus is a **first-person sailing trainer** that exercises reusable ship mechanics. APEX's wider game remains the long-term goal. Keep the working steering wheel and a coherent, historically inspired ship; exact period reconstruction is secondary to understandable operation.

**START GUIDED LESSON** introduces the port fore sheet and steering wheel through walk-up station controls, with optional **ENTER VR** on supported headset browsers. [First Watch controls and current limits](docs/first-watch-lesson.md). Use **MENU → ENGINEERING TOOLS** for inspection and the development controls.

In the workshop, start on deck, walk with the arrow keys or on-screen arrows, and look with right-mouse drag or a drag on the right side of the touchscreen. A/D operate the helm, W/S change effective sail area, and Q/E trim the yards. F switches between the deck and fly inspection; P hides/restores the HUD. Buttons provide the same sailing commands on touchscreens.

**PHYSICS TRIAL** enables displaced-volume buoyancy, individual sail pressure loads, and the loaded wheel → drum → two steering lines → tiller → rudder transmission. The lower foreyard also has two pressure-loaded braces: select a line, haul/ease, belay, let it run free or cut it. [Brace controls and model](docs/yard-brace-trial.md) explain operation. The same lower fore sail now has a deforming membrane and two loaded clew sheets. Select **CONTROL: CLEW SHEETS** to haul/ease, belay, free or cut them. [Membrane model, controls and evidence](docs/sail-membrane-trial.md). The earlier controlled prototype remains available. Web builds also accept `?simulation=forces`.

The weather selector controls a seeded evolving atmosphere and shared irregular sea, with broken whitecaps, wake, clouds, rain, fog and lightning; thunder is optional. **CO-OP** joins a running native WebSocket host, with one authoritative ship, exclusive stations and replicated crew/weather. **ENTER VR** is an experimental WebXR adapter enabled only on supported browsers. [Setup, current evidence and completion gates](docs/shared-sailing-simulation.md) distinguish these implemented prototypes from full running rigging/cloth, a deployed multiplayer service and headset-validated training.

## Run locally

Restore the original source model before importing the project:

```sh
base64 --decode assets/apex_pinnace_v9.glb.xz.base64 | xz --decompress > assets/apex_pinnace_v9.glb
```

Open `project.godot` in Godot 4.7.2 and run `physics_trial.tscn`. For the Web export, install the matching export templates and use the `Web` preset. GitHub Actions imports, exports, runs native regressions, and checks the rendered browser build. Pull requests produce review artifacts; main's workflow handles Pages deployment.

## Realism prerequisites

[The canonical simulation checklist](SIMULATION_REALISM_REQUIREMENTS.md) defines the structural, rigging, weather/water, cloth, VR, crew, combat and training evidence still required. The present prototype does not satisfy whole-ship realism or validated VR training.

## Reuse the mechanics

The scene-independent `scripts/hull_hydrostatics.gd` accepts hull sections, body state and a water-height callback; `scripts/steering_transmission.gd` accepts helm effort and water hinge torque. They return forces/moments or steering state without depending on APEX's camera, input or assets. [Integration examples and limits](docs/reusable-ship-mechanics.md) describe the contracts. The full vessel is not yet packaged as a drop-in asset.

[Physics assumptions and verification](docs/physics-foundation.md) · [Ship construction evidence](docs/ship-refit.md) · [Active QA ledger](QA_ACTIVE_CHECKLIST.md)

Fore-sail rest-shape and spar-contact evidence: [controlled wind cycle](docs/realism/fore-sail-cycle.md). One of eight sails is physically deforming; full running rigging, cloth folds/self-contact and hardware VR acceptance remain open.
