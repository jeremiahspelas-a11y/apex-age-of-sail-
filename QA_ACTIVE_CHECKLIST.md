# APEX Active QA and Implementation Ledger

Updated: 2026-10-28. This is the source of truth for what was *actually* verified.

## Force-driven training foundation — 2026-10-28
- User authorized beginning coupled mechanics, then clarified the goal: a functioning, historically inspired ship suitable for future VR education; **keep the steering wheel**. Exact 1670–1690 reconstruction does not override that preference. Wheel is default; provisional whipstaff remains an optional configuration.
- Added an opt-in PHYSICS TRIAL with displaced-volume buoyancy, restoring moments, empirical dissipative water resistance, eight individual sail-pressure loads and real unlocked rigid-body motion. The earlier prototype remains selectable. Ocean surface now exposes the shared `get_height` API requested by the ship.
- First loaded mechanism: crew-limited wheel torque → drum payout → two tension-only elastic steering lines → tiller/rudder. Water load can backdrive a released wheel; cut lines transmit no force. Added visible drum, line routes and blocks plus a direct torque adapter for later VR input.
- Local native tests verify analytical buoyancy/force center, grid convergence/equilibrium/cargo draft, restoring heel moment, damping energy, actual engine impulse/recovery, sail loads, line energy decay/backdriving/disconnection and control limits. Construction and Spatial QA regressions also pass. Local Chromium entered force mode and reported finite motion, 80,000 kg mass, ~78.22 m³ immersion and ~785.8 kN buoyancy, with no browser errors.
- Mass/CG/inertia, crew effort, line elasticity and hydrodynamic coefficients are provisional. This is not full rope/cloth dynamics, calibrated sailing instruction, VR support, or physical-device performance acceptance. See [physics foundation and limits](docs/physics-foundation.md).

## Actual ship construction refit — 2026-10-28
- User correction: work on the ship itself. This pass refits the retained original pinnace's hull/decks, fittings, sails, rigging and walking surfaces; earlier inspection-tool work remains separate in the history.
- Measured the original GLB directly: V6 hull has **zero boundary/nonmanifold edges** already; the old fairing-study hull has 176 boundary edges. The visible bow/stern problem was not proof that V6 itself was open. Multiple rectangular deck generations overlap and overhang the tapered V6 ends; fixed-width frames and rigging also miss their intended supports.
- Refits the existing V6 station geometry to a deck rim, fits the original solid deck nodes to those lines, encloses raised-deck sides, completes both companion stairs, and fits rails/frames/lower-deck planks. The old 176-piece duplicate rib scaffold is no longer generated, and support beams avoid the hatch openings. Original source GLB checksum and all original nodes are retained; superseded visible duplicates are hidden conditionally.
- Real socket pivots now carry the original helm assembly, rudder/tiller, eight sail/yard pairs, doors and hatches. Curved cloth, named materials, shared grain/planking/canvas shaders, mast steps/partners, shrouds/ratlines/chainplates and stays are implemented. This is not a new rope/cloth/hydrostatics solver.
- **Local native tests pass:** hull reference envelope (379.69 m³, two incident triangles per welded edge), unchanged V6 beam/length/draft bounds, sail/yard attachment under trim, ten-part helm pivot, hinges, eight canvas materials, deck raycasts, open-hatch clearance and real CharacterBody traversal to both raised decks. Spatial QA regressions also pass.
- Neutral-light Chromium ship views were rendered and inspected; before/after evidence shows removed deck flicker/overhangs, tapered closed upperworks, curved sails and anchored standing rigging. See [ship refit evidence](docs/ship-refit.md). CI evidence belongs to the latest PR head; physical Android acceptance is pending.
- Preserved construction-first scope: the 34 m³ prototype physics model, full running-rigging mechanics, surveyed historical plan, hold clearances, damage graph, ocean/sky and mobile performance remain unfinished. Do not mark those complete from this refit.

## God Mode and Spatial QA stabilization — 2026-10-28
- Resumed from `7cd96530`, whose GitHub Actions run `40728831700` completed successfully. Scope: stabilize existing fly → point → describe → save → continue flow; preserve original ship asset and design.
- Reproduced stale selection on the original code: `begin_pin()` retained an earlier mesh selection and allowed a note to save without selecting a new surface.
- Clear pending selections/previews on restart/cancel; a missed ray stays in picking mode; reject blank notes; freeze the flight camera throughout selection and editing. Clear held input on pinning, mode change and application focus loss; process touch releases before GUI consumption. Place UP/DOWN between the sticks rather than over the right stick.
- Saved pins now carry visible numbers and remain children of the selected ship mesh. Hide HUD cancels pending annotations and retains SHOW HUD.
- Local Godot **4.7.2**: import and Web release export passed; `tests/spatial_qa_test.gd` passed real triangle hit/miss, save/cancel, mesh-following numbered marker, JSON export, independent two-finger stick state, release cleanup, editing freeze and mode transitions.
- CI now runs the interaction test on pull requests as well as main. PR builds produce artifacts without deploying or cancelling main's Pages run. Tests are excluded from the exported game.
- Local Chromium with Pixel 7 emulation at 960×540: opened and inspected flight controls, selected a real imported cannon-barrel triangle, typed and saved a note, then downloaded and parsed `apex-spatial-qa.json` with the expected description, mesh path, local point and triangle index. Flight, editor and saved-pin screenshots were visually reviewed; no browser console/page errors were captured. CI repeats this export assertion.
- Physical Android acceptance and browser multi-touch behavior remain pending; headless event tests alone do not establish Android usability. Unresolved ship construction/water/sky issues below remain open.

## Ship silhouette restoration and noon lighting — 2026-10-27
- New Android screenshots show bow/stern outline appears blocky/open, non-period-looking protruding rods, flat canvas, repeating clouds, and mirror-like blue water. **These are now the most urgent visual priorities**; rig and gameplay features are paused. Screenshots are evidence for the user-visible deployed version, not necessarily this commit.
- The imported GLB contains both `legacy_000_Fairing-study wooden hull` and `V6_closed_hull`; keep the latter and hide the overlapping older fairing-study mesh only when both are found. This is a non-destructive test of whether that duplicate causes the ugly bow and stern. If the old fairing proved necessary, revert this specific visibility setting, not the full ship.
- Set time to **12:00 noon** and correct sun's declination: at noon the sun ray points downward rather than grazing the ship horizontally. Retain the moving sun/moon, clouds, storm and wind cycle. Increase first long ocean swell lengths and amplitudes (115m/0.67m and 70m/0.45m), reduce high frequency chop; CPU wave math and GPU shader read from one shared parameter array.
- Audit confirms both named original hulls before the hide is allowed; no bow/stern caps claimed as repaired until screenshot inspection. Protruding spars remain unresolved, require per-mesh origin audit.
- Acceptance: Godot CI passes with 288 meshes, exactly eight original sail/yard pairs; screenshot confirms noon, double hull reduction, and no new visual seams. Android verification pending.

## Verified original projection audit — October 27
- CI workflow `40602709174` **SUCCESS** (commit `f5008fc6`): the original GLB has both historical fairing-study and V6 closed hull meshes; at runtime the older one was successfully hidden.
- Actual protrusion log recorded **exactly one mesh outside the coarse hull bounds:** `legacy_053_Bowsprit`, center `(0.002198, 3.55212, -15.69901)`. A bowsprit is historical and may be correct; do not delete it without measuring its root and orientation.
- Those small brown projections above deck are still visually unresolved: hull-boundary search could not identify their names. Next audit now reports mesh names/centers/sizes for vertical mid-deck projections, separately from legitimate far-forward bowsprit.
- **No bow/stern completion claim:** V6 name and visibility are not proof the mesh is manifold or visually sealed. Require camera close-ups.

## 2026-10-27 structural gate — verified status and reuse candidates
- Build `40602159670` on `7883a11d` **FAILED** due to Godot type inference of `local_center`; correction `e09ec1ae` is **queued**, not verified. Do not attempt further hull modifications until headless import + browser screenshot pass.
- Confirmed source: `V6_closed_hull` remains, earlier `legacy_000_Fairing-study wooden hull` is hidden on scene readiness if both nodes exist; final bow/stern closing is **NOT** established by this visibility choice. Before calling this resolved, verify mesh watertightness/visual ends by 3D views and model topology.
- Protruding pieces: name/position diagnostic is now present, but its running result has not been retrieved; do not delete named original meshes without verifying whether they're rigging/anchor/spar components.
- Reuse research: `Ocean3D-Org/ocean3d-lite` already credited in project; `stvgale/Gerstner-Waves-Buoyancy-Effects-Godot-4` is another possible wave/buoyancy reference, and `LesusX/Water-Shader` a possible water-material reference. No code imported from them in this step; verify licenses and browser compatibility first.
- **Next executable gate**: Wait for repaired CI run to complete, retrieve `APEX PROJECTION AUDIT` lines and browse scene screenshot, then classify exact mesh IDs as legitimate spars vs legacy visual artifacts. Resolve bow/stern only with geometry evidence; do not mislabel an audit as a fix.

## Daylight-first procedural world and audit maintenance — October 27
- User decision: **start at 10:00 AM**, with clear useful daylight, but preserve a progressing procedural 24-hour sun/moon/ambient cycle (6 AM sunrise, 6 PM sunset under the simplified sine model). Weather/cloud/wind stay procedural. No fixed perpetual daylight.
- Updated `scripts/weather_controller.gd` to initialize phase from exported `starting_hour=10.0` and removed old pre-dawn solar phase offset. Updated `scripts/audit_original_rig.gd` to remove stale statements claiming old mast coordinates and an active duplicate procedural hull; these had already been corrected in code.
- Verify through GitHub import/export and browser smoke tests; daylight at startup and continuous sunrise/night transitions need **separate time-controlled visual QA**. Do not mark VIS-05 visually fixed from code alone.
- Prior `fceff0dc` workflow 40600402834 **SUCCESS** including web deployment. The GLB audit from cd316398 is now included in that passing run (inspect logs for `RIG PAIR PASS` if necessary).

## Active visual-defect register — Android capture 1000079261.mp4 (20.9 s, user-provided prior-build footage)
Evidence interpretation: source video shows the *preceding* deployed version, not necessarily current HEAD; sampled seven evenly spaced frames covering the clip. This is user-captured Android visual evidence, **not** evidence that current later commits failed. Never mark fixed merely because CI passes.

| ID | Observed defect or question | Diagnosis / target fix | Verification requirement | Status |
| --- | --- | --- | --- | --- |
| VIS-01 | Water has long bright linear streaks and large saturated patches across several camera angles | Check ocean roughness, foam and wave shading; preserve wave dynamics and night reflection | Comparison of equivalent camera/time screenshots after shader deployment, with no broad white bands | OPEN — source video predates a44e17ac; shader commit's run 40599856228 cancelled, so unverified |
| VIS-02 | Sails look rigid and geometrically flat from front/side | Keep eight original sail meshes and paired yards; add modest curvature/cloth behavior only after transforms confirmed | All eight pairs attached and visibly responding to sheet input without gaps | OPEN — 4543a49e CI passed (run 40599525624), but no trim-input behavior test |
| VIS-03 | Sail plan is square-panel dominant and not yet visually credible for the 1670–1690 armed pinnace target | Research period-compatible sail proportions and mizzen without replacing base ship | Historical design comparison and multi-angle Android approval | OPEN — preservation rule applies |
| VIS-04 | Bright polygonal cloud puffs, sometimes intruding into HUD area | Clouds are seven scaled spheres per bank; improve alpha, placement, depth and silhouette | Capture day, dusk, night with sky visible; no obvious repeated polygon clusters or UI occlusion | OPEN |
| VIS-05 | Very dark/blank horizon sky despite brightly lit sails and water | Audit moon/sun direction, ambient, sky shader, exposure and phase synchrony | Day/night time-lapse with readable moonlit hull and believable sky transition | OPEN — 1a8f821d built, visual regression not measured |
| VIS-06 | Protruding long beams/rod-like forms visible over sea to port and starboard | Trace exact GLB mesh names vs stays/yard geometry and underwater reflections; don't delete speculatively | Report original mesh IDs, positions and multi-angle evidence; visually remove only accidental duplicates | INVESTIGATE |
| VIS-07 | Hull appears low-detail/boxy at some views; original exterior must not be replaced | Verify imported hull mesh silhouette and any extra procedural geometry overlap | Distinct side, bow, stern, oblique screenshots and hull bounds | INVESTIGATE |
| VIS-08 | Tiny top HUD, action controls and bottom walking controls have poor readability on portrait phone | Make responsive safe areas, larger touch targets, avoid browser chrome | Android portrait screenshot showing non-overlapping legible touch controls | OPEN |
| QA-01 | Last commit cd316398 only adds GLB sail-yard pairing *audit*, not new rendering | Log eight matching pairs and fail missing pairs; also test input-driven angle and unchanged attachments separately | CI import plus rig audit success; report pair count explicitly | PENDING — run 40600034828 in progress on last check |
| QA-02 | Older ledger claimed GLB rudder and wheel control as connected, but visible movement not measured | Inspect runtime bind log and drive rudder with port/starboard input | Observed original blade deflection and helm movement | UNVERIFIED |
| QA-03 | Consecutive commits cancel CI runs; prevents actual release verification | Batch code, tests and ledger in one commit; compare screenshot artifacts to commit ID | Every change linked to commit SHA, workflow conclusion, screenshot, user footage revision | ACTIVE PROCESS RULE |

Priority: first make QA deterministic and establish exact deployed SHA, then fix glaring water/sky issues, then rig attachment/pivots, then cloth and period shaping. Do not interpret source-only audits as visual fixes.

## Evidence grades
- **COMMITTED**: source exists on main. Does not prove it compiles.
- **BUILD PASS**: Godot import/export and 100-frame headless smoke test pass.
- **BROWSER PASS**: Playwright creates two screenshots, finds a canvas and no captured WebGL/shader errors.
- **VISUALLY REVIEWED**: screenshots opened and inspected by developer; observable behavior compared to acceptance criteria.
- **USER VERIFIED**: user confirms it works on their Android phone.
Never mark visually complete based on a GitHub build or commit alone.

## Original-rig control binding — next engineering step
- Previous sun/moon, material and preservation change commit 1a8f821d: GitHub Actions run 40597627425 **SUCCESS** (build, browser and deployment), Android visual confirmation remains pending.
- Control integration now binds working rudder and helm spin to existing named GLB `rudder_blade` and `V9_helm_wheel_hub` meshes where found, leaving imported geometry intact. Missing mesh names are safe no-op with an explicit runtime log; steering calculation persists. SteeringRope added as separately queryable initial-state registry component with signal sync.
- GLB rudder and wheel mesh axes/rotation behavior still require screenshot and browser verification; the original eight yard/sail pairs remain untouched until pivots and pairing are measured.

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
