# APEX Active QA and Implementation Ledger

Updated: 2026-10-27. This is the source of truth for what was *actually* verified.

## Evidence grades
- **COMMITTED**: source exists on main. Does not prove it compiles.
- **BUILD PASS**: Godot import/export and 100-frame headless smoke test pass.
- **BROWSER PASS**: Playwright creates two screenshots, finds a canvas and no captured WebGL/shader errors.
- **VISUALLY REVIEWED**: screenshots opened and inspected by developer; observable behavior compared to acceptance criteria.
- **USER VERIFIED**: user confirms it works on their Android phone.
Never mark visually complete based on a GitHub build or commit alone.

## Current tracked work
| ID | Feature | Status | Evidence / next required test |
|---|---|---|---|
| QA-01 | Automated Godot build and browser screenshots | BUILD PASS on 99e836bd | Browser screenshot capture workflow exists; QA artifacts on GitHub |
| QA-02 | Public screenshot proof alongside playable game | COMMITTED cde1e65e | Next successful deployment must expose /qa/initial.png, /qa/after-5s.png, /qa/report.json and /qa/commit.txt |
| SKY-01 | Physical sky and sun disc | COMMITTED 20a51f7b | Screenshot must show sun in camera view; check daylight and storm lighting |
| SKY-02 | Irregular multi-lobe 3D cloud banks | COMMITTED 20a51f7b | Screenshot must show recognizable cloud silhouettes without discs; verify mobile frame time |
| SEA-01 | Distant ocean patches | COMMITTED 797a7c9c; build initially FAILED | Failure: missing horizon_patches declaration; fixed 828cd144. Verify export, edge-free horizon, patch seams and camera-follow |
| SHIP-01 | Mechanical helm yaw force | BUILD PASS 99e836bd | Needs behavioral steering/rope-cut test and Android confirmation |
| SHIP-02 | Flooding compartments | BUILD PASS on prior version | User screenshot shows FLOOD 0.0 t and buttons; needs breach/sink behavior test |
| SHIP-03 | Floating ship geometry and detached-looking fittings | OPEN | Audit 288 mesh transforms, local/global origins, sail attachment, collision, lighting |
| SHIP-04 | Real sail cloth geometry, thickness, aero forces and rigging | OPEN | Replace static planar sails and verify mast/yard attachments |
| QA-03 | Automatic visual assertions, not only screenshot generation | OPEN | Add horizon, sun, cloud, HUD, ship silhouette and sail motion assertions |
| QA-04 | Mobile Android 30 FPS performance | OPEN | Need browser GPU timings and Android confirmation |

## Required regression loop for each change
1. Commit targeted source change and ledger entry.
2. Check latest GitHub Actions build; on failure inspect logs and repair before new features.
3. Inspect public /qa/initial.png and /qa/after-5s.png from the **same deployed commit**.
4. Compare rendered evidence against acceptance criteria; document failures, do not mark complete.
5. Offer PLAY GAME link; request user confirmation only for interactions that cannot be automatically tested.
6. Record user-confirmed results here in a subsequent commit.

## Most recent user-supplied visual evidence
Screenshot 2026-10-27: finite circular ocean boundary, missing visible sun/clouds, dark ship, disconnected-looking fittings, rigid rectangular sails, tiny HUD. These are **open defects** until verified fixed in new screenshots.
