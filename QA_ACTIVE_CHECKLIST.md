# APEX Active QA and Implementation Ledger

Updated: 2026-10-27. This is the source of truth for what was *actually* verified.

## Evidence grades
- **COMMITTED**: source exists on main. Does not prove it compiles.
- **BUILD PASS**: Godot import/export and 100-frame headless smoke test pass.
- **BROWSER PASS**: Playwright creates two screenshots, finds a canvas and no captured WebGL/shader errors.
- **VISUALLY REVIEWED**: screenshots opened and inspected by developer; observable behavior compared to acceptance criteria.
- **USER VERIFIED**: user confirms it works on their Android phone.
Never mark visually complete based on a GitHub build or commit alone.

## Latest independently checked evidence
- Successful build and deployment: workflow 40591984672, commit f06be355. Visual QA archive retrieved and both initial.png and after-5s.png manually opened. Playwright: canvas=1, errors=[].
- **Visual finding:** Both frames show a very dark ship with rigid sails; no visible clouds or sun from that camera angle; water now covers the image but has conspicuous bright streaks and an unnatural appearance. Do not certify cloud/sun appearance or ship geometry from these frames.
- **Change in development sequence (user-directed):** Prioritize accurate ship **construction, connected geometry, deck mechanics and realistic sail/rigging shapes** ahead of exterior sailing physics and wind-force tuning. Keep current physics as a prototype; do not call it mechanically complete.

## Current tracked work
| ID | Feature | Status | Evidence / next required test |
|---|---|---|---|
| QA-01 | Automated Godot build and browser screenshots | BUILD PASS on 99e836bd | Browser screenshot capture workflow exists; QA artifacts on GitHub |
| QA-02 | Public screenshot proof alongside playable game | BROWSER PASS f06be355 | CI passed, both images retrieved and reviewed. Inspect published /qa URLs when needed |
| SKY-01 | Physical sky and sun disc | COMMITTED 20a51f7b | Screenshot must show sun in camera view; check daylight and storm lighting |
| SKY-02 | Irregular multi-lobe 3D cloud banks | COMMITTED 20a51f7b | Screenshot must show recognizable cloud silhouettes without discs; verify mobile frame time |
| SEA-01 | Distant ocean patches | COMMITTED 797a7c9c; build initially FAILED | Failure: missing horizon_patches declaration; fixed 828cd144. Verify export, edge-free horizon, patch seams and camera-follow |
| SHIP-01 | Mechanical helm yaw force | BUILD PASS 99e836bd | Needs behavioral steering/rope-cut test and Android confirmation |
| SHIP-02 | Flooding compartments | BUILD PASS on prior version | User screenshot shows FLOOD 0.0 t and buttons; needs breach/sink behavior test |
| SHIP-03 | Floating ship geometry and detached-looking fittings | OPEN; interior timber skeleton COMMITTED 7fdd4a5e | 11 frame stations, floors, keelson, longitudinal stringers and deck beams now generated relative to boat; inspect build and interior screenshots; not yet a watertight hull or fastener graph |
| SHIP-04 | Real sail cloth geometry, thickness, aero forces and rigging | OPEN | Replace static planar sails and verify mast/yard attachments |
| QA-03 | Automatic visual assertions, not only screenshot generation | OPEN | Add horizon, sun, cloud, HUD, ship silhouette and sail motion assertions |
| QA-04 | Mobile Android 30 FPS performance | OPEN | Need browser GPU timings and Android confirmation |

## Construction-first execution order
- [x] Audit previous deployed screenshots and browser error report (f06be355); note visible deficiencies.
- [x] Add prototype parented keelson, floor timbers, transverse frames, deck beams, side stringers (7fdd4a5e), **commit only; not visually checked**.
- [ ] Compile new construction commit in Godot and run WebGL smoke test.
- [ ] Capture deck-level and below-deck screenshots, not only orbit view, with the new timber visible.
- [ ] Reconstruct a historically supported **hull geometry** and match model stations and mass; no sealing assumptions based on disconnected boxes.
- [ ] Design and model walkable decks, hatches, stairs, headroom and collision surfaces that line up.
- [ ] Connect fixed rigging to actual mast/yard hardware, then implement deformable sails.
- [ ] Only after ship is structurally and mechanically verified: replace scripted wind/sailing motion with force integration.

## Required regression loop for each change
1. Commit targeted source change and ledger entry.
2. Check latest GitHub Actions build; on failure inspect logs and repair before new features.
3. Inspect public /qa/initial.png and /qa/after-5s.png from the **same deployed commit**.
4. Compare rendered evidence against acceptance criteria; document failures, do not mark complete.
5. Offer PLAY GAME link; request user confirmation only for interactions that cannot be automatically tested.
6. Record user-confirmed results here in a subsequent commit.

## Most recent user-supplied visual evidence
Screenshot 2026-10-27: finite circular ocean boundary, missing visible sun/clouds, dark ship, disconnected-looking fittings, rigid rectangular sails, tiny HUD. These are **open defects** until verified fixed in new screenshots.
