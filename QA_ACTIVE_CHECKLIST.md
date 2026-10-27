# APEX Active QA and Implementation Ledger

Updated: 2026-10-27. This is the source of truth for what was *actually* verified.

## Evidence grades
- **COMMITTED**: source exists on main. Does not prove it compiles.
- **BUILD PASS**: Godot import/export and 100-frame headless smoke test pass.
- **BROWSER PASS**: Playwright creates two screenshots, finds a canvas and no captured WebGL/shader errors.
- **VISUALLY REVIEWED**: screenshots opened and inspected by developer; observable behavior compared to acceptance criteria.
- **USER VERIFIED**: user confirms it works on their Android phone.
Never mark visually complete based on a GitHub build or commit alone.

## Screenshot-driven night/day rig preservation change — October 27
- Android screenshot shows *nighttime* dark silhouette with poor moonlit readability, duplicate-looking spars and stiff original square sails. User confirms darkness is from desired procedural day/night weather; **retain dynamic cycle** rather than force full daylight.
- This single atomic change introduces opposing sun/moon directional lights and time-varying ambient illumination, keeping storm influence; improves original material base tones and removes multiplicative dark noise; removes redundant generated box-shaped wheel/rudder/yard visuals while retaining steering state pivots; prevents incorrectly scaled duplicate exterior procedural shell and moves camera out slightly.
- Original imported GLB 288-mesh asset preserved. Functional animated GLB rigging, sail cloth deformation, and historical fitting alignment remain subsequent engineering tasks. Source change pending CI and Android inspection.

## Latest independently checked evidence
- Successful build and deployment: workflow 40591984672, commit f06be355. Visual QA archive retrieved and both initial.png and after-5s.png manually opened. Playwright: canvas=1, errors=[].
- **Visual finding:** Both frames show a very dark ship with rigid sails; no visible clouds or sun from that camera angle; water now covers the image but has conspicuous bright streaks and an unnatural appearance. Do not certify cloud/sun appearance or ship geometry from these frames.
- **Change in development sequence (user-directed):** Prioritize accurate ship **construction, connected geometry, deck mechanics and realistic sail/rigging shapes** ahead of exterior sailing physics and wind-force tuning. Keep current physics as a prototype; do not call it mechanically complete.

## Reuse and research audit
- Adopted: Godot native MeshInstance3D and CylinderMesh for curved rib stations; no external code licensing or plugin install needed. Godot's official procedural geometry guidance explains ArrayMesh and SurfaceTool for upcoming continuous hull shell: https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/index.html
- Evaluated but **not copied**: Gaea for Godot (MIT; primarily procedural terrain, not historical wooden hull geometry): https://github.com/gaea-godot/gaea . Do not add irrelevant dependencies simply because they are open source.
- Reference ship lines are still required before claiming historical fidelity. Procedurally curved ribs currently use provisional station formulas, not a specific historic ship plan.

## Measured alignment repair
- Original rig inventory measured fore/main/mizzen mast centers at z = -6.5, 3.1, 10.8 and y = 10.15, 11.65, 7.65, respectively; original mast heights = 17.7, 20.7, 12.7. Updated **mast collision geometry only** to these centers/sizes in commit 39232bc4. Original GLB visual meshes unchanged.
- This is a source commit, **not yet a confirmed build or physical collider pass**. Next checks: Godot import/runtime, screenshots, and collision movement around mast bases. Generated yards, rudder, decks, hull overlays remain under preservation hold.

## Original asset inventory — recovered from cancelled run 40596114168
- Actual Godot GLB import completed and emitted: **288 original meshes**, original aggregate AABB position `(-6.25,-3.5,-19.06155)`, size `(12.5,25.5,34.01155)`.
- Original name-match counts: `mast=3`, `yard=8`, `sail=8`, `wheel=9`, `rudder=5`, `deck=45`, `hull=2`, `cannon=4`. Counts are mesh name classifications, not guaranteed independently functional parts.
- **Confirmed scale/extent discrepancy:** procedural hull z range `[-10.9,+10.9]` spans 21.8 units, while imported rig bounds extend from approximately `-19.06` to `+14.95` (34.01 units), so newly generated skin is not coextensive with the original model. The hull-specific mesh bounds have not yet been isolated, so 34.01 units is *overall rig extent*, not necessarily hull length.
- New animated rudder z=13.6 and mast colliders z=[-5.5,1.2,8.0] are unverified against five original rudder meshes and three original mast meshes. Nine original wheel-related meshes indicate likely duplicate helm fittings; **do not delete either until inspecting actual mesh transforms and screenshots**.
- Next audit run b6fb94de is in progress; it adds per-component centers/dimensions. Do not call build success or visual correctness before completion.
- **Construction HOLD:** no new hull, sail, mast, helm, yard, or rudder geometry until components are matched against the original rig and duplicate overlaps resolved safely.

## STOP-GATE: original rig preservation audit
- Do not add or move rigging, masts, rudder, yards or replace the original GLB until original parts and positions have been inventoried and reviewed.
- **Confirmed from current source (not visual confirmation):** original GLB remains instanced as `HullVisual`; new hull strakes, keel bottom and end caps are additional geometry, so overlapping duplicate hull is possible.
- **Coordinate discrepancies:** mast colliders z=-5.5,1.2,8.0 versus new animated yards z=-6.5,0.0,6.0; procedural shell ends at z=+10.9 while rudder is at z=+13.6. Neither is proof of a defect without GLB coordinate comparison.
- **Potential era mismatch:** the prototype `HelmWheelHub` is not proof that the original vessel had a ship's wheel; circa 1670–1690 tiller/whipstaff may be more appropriate, pending evidence and original model inventory.
- Added read-only Godot original GLB mesh inventory and AABB report (`scripts/audit_original_rig.gd`, commit 12227d03), invoked by CI (71373b8). Build results and report still pending.
- [ ] Read actual CI inventory output; check mesh count, bounding box, mast, yard, sail, steering and hull names.
- [ ] Compare original mast/yard/rudder world transforms against new generated components; document measured offsets before modifications.
- [ ] Inspect deck and exterior browser screenshots for overlap and occlusion.

## Historical vessel baseline and third-party evaluation
- This user's preservation constraint takes precedence over earlier sloop proposal. Retain existing game scene/GLB and focus on historically plausible detailing and rigging; existing visual sail proportions must be inspected before changing mesh geometry.
- **USER-LOCKED DESIGN BASELINE:** Preserve the existing three-masted `apex_pinnace_v9.glb` as the reference silhouette and layout. Interpret it as a **late-17th-century armed pinnace / small three-masted merchant-privateer, circa 1670–1690**, subject to later plan verification. This is a design identity, not proof that the model matches any surviving vessel. **Do not substitute a single-masted sloop, boxy square-sail-dominated ship, or modern yacht.** No wholesale hull replacement without a demonstrated need. Keep the existing three masts, hull, deck layout, and fittings wherever practicable; prioritize period-consistent wooden spars, mixed sail plan including lateen mizzen where appropriate, rope-operated mechanisms, and historically appropriate hardware. Avoid engines, modern winches, yacht rails, modern sail materials and modern steering gear. Do not remove all square sails merely to avoid a boxy silhouette; refine their shape and proportion.
- Rope candidates researched: MIT `mikest/halyard` https://github.com/mikest/halyard (Godot 4.5+, simulation with anchors and nautical roadmap, native build/integration risk for browser); MIT `sanyabeast/verlet_rope_4_gd` https://github.com/sanyabeast/verlet_rope_4_gd (GDScript 3D rope and attachments; preferred evaluation path for Android web); MIT `mphe/GDNative-Ropesim` https://github.com/mphe/GDNative-Ropesim (2D C++ GDExtension; not suitable for immediate WebGL ship rigging). **No third-party code copied or installed yet.**
- Build 40595277007 FAILED: `ship_assembly.gd` used `is_connected`, colliding with Godot `Object.is_connected(StringName, Callable)`. Renamed to `is_assembly_connected` (aaf9373b); rerun is required before adding other code.
- [ ] Choose a documented *specific* historic hull lines plan and reconcile proportions, sail plan, tiller steering, and GLB model with it.
- [ ] Inspect license and Godot/HTML5 compatibility of GDScript rope addon before vendor-integration.

## Master-rig connection implementation — October 27
- MasterAssembly now subscribes to the helm's `steering_connection_changed` signal; toggling ROPE CUT records `steering_rope_connected` without falsely disconnecting all helm machinery (commits a6b7861b and 2cd5349b). **Source integrated; runtime verification pending.**
- [ ] Confirm master assembly initializes and event fires when ROPE CUT is pressed.
- [ ] Move steering wheel, pulley, rope and rudder to independently reusable PackedScene subassemblies with explicitly defined attachment sockets.

## Master rig integration (new)
- Added `scripts/ship_assembly.gd` (d3c8c528) and mounted `MasterAssembly` on the Boat scene (429fe682). The registry discovers HullVisual, ShipStructure, ShipIntegrity, Mechanisms and Wetness, verifies required subassemblies, and exposes connection status. **This is a master assembly interface, not physical fasteners, constraints, or a skinned rig.**
- [ ] Verify Godot scene startup, registry populated, and no missing assemblies.
- [ ] Connect helm rope failure, mast failures, structural fasteners, and detachable parts to master assembly events.
- [ ] Create documented attachment sockets and transform inheritance tests for sails, rigging, steering, hull and interior.

## Current construction step
- Added `GarboardAndKeelBottom` with indexed triangles connecting provisional port/starboard garboard lower edges to a central keel line; commit d53ea22a. **Not certified watertight**, remains open at top, not yet rendered/validated. This change follows earlier port/starboard planking and end-cap prototypes.
- Latest previous Actions run 40594769813 was still in progress when checked. Several preceding runs were cancelled by newer commits; a cancelled run is not a build pass.

## Latest verification and regression work
- Workflow 40594611876 was still running when checked; no evidence yet that the bow/stern visual closure release deployed.
- Added a source-level build regression assertion for both end closures in CI (commit c03bbc8b). This is **not** a watertight manifold test and does not substitute for inspecting screenshots.
- Next essential verification: inspect fresh browser captures from the latest successful run, then use a topological edge-incidence check on a unified shell before calling it sealed.

## Latest direct changes
- Commit 8db88822: add separately named bow and stern visual closure panels following existing hull stations. These are **not certified watertight** (surface topology and deck/keel edges remain to test).
- Build for prior planking+QA commits was still pending or cancelled when checked; **do not claim those builds passed** until a successful run reports their inclusion.

## Latest hull construction iteration
- Latest verified deployment before new hull panels: workflow 40593421078, commit ed79fe39, success.
- Added 16 separately named port/starboard outer strake mesh panels, using the same station profile as the curved ribs, with indexed Godot ArrayMesh triangles (commit 2c3b9c56). This is a **provisional visual hull**, not watertight or historically authenticated; no fracture or plank fasteners yet.
- Expanded CI source-level checks for the new strake generation (commit d9de714d). New build and screenshot inspection still required.

## Latest CI improvement
- Added a deterministic CI test of native timber construction presence, eleven station loop, tapered rib geometry and local-to-ship member placement (commit 41b21aed). **This is a source-level regression test, not structural physics validation.** The corresponding build result and screenshots must be checked before accepting it.

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
| SHIP-03 | Floating ship geometry and detached-looking fittings | OPEN; curved rib stations COMMITTED ed84828c | 11 provisional hull stations now use curved ribs (8 segments per side), tapered half-beam and sheer plus keelson/stringers/deck beams; still no certified lines, sealed shell or fastener graph. Godot/browser render check pending |
| SHIP-04 | Real sail cloth geometry, thickness, aero forces and rigging | OPEN | Replace static planar sails and verify mast/yard attachments |
| QA-03 | Automatic visual assertions, not only screenshot generation | OPEN | Add horizon, sun, cloud, HUD, ship silhouette and sail motion assertions |
| QA-04 | Mobile Android 30 FPS performance | OPEN | Need browser GPU timings and Android confirmation |

## Construction-first execution order
- [x] Audit previous deployed screenshots and browser error report (f06be355); note visible deficiencies.
- [x] Add prototype parented keelson, floor timbers, transverse frames, deck beams, side stringers (7fdd4a5e), **commit only; not visually checked**.
- [ ] Compile new construction commit in Godot and run WebGL smoke test.
- [ ] Capture deck-level and below-deck screenshots, not only orbit view, with the new timber visible.
- [x] Replace rectangular upright frame placeholders with provisional curved station ribs (ed84828c); code committed, **not tested yet**.
- [x] Add provisional continuous port/starboard strake geometry tied to rib stations (2c3b9c56); **source committed, awaiting render QA**.
- [x] Commit provisional bow and stern visual closure panels (8db88822); build and render pending, not a certified closed manifold.
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
