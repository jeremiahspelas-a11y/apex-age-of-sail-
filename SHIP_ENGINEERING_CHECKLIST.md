# APEX Ship Engineering — measurable implementation checklist

**Goal:** A historically grounded, walkable, mechanically operable, damageable wooden sailing vessel. A naval hull is *not* simulated correctly by treating every plank as a free rigid body. In normal operation, connected structure behaves as an assembled rigid hull; impact/fracture detaches selected pieces. Watertight integrity is simulated via closed hull-shell topology and hydraulic compartments. Sailing forces must transfer through sails, rigging, spars, mast steps, hull, and rudder to the water.

## Rules for checking an item
- [x] means **present in repository and confirmed by a successful Godot build**; it does not mean visually or physically validated unless the test says so.
- [ ] means absent, incomplete, or unverified. **Never mark complete from a design mockup, GitHub commit alone, or headless export.**
- Each subsystem needs: dimensions/materials, coupling to neighboring systems, automated tests, rendered screenshots, Android performance tests.

## October 28 force-driven trial

The first loaded lower-foreyard brace circuit is also integrated: two ideal fixed-block leads, belaying pins, bounded hand effort, hauling/easing, free payout and cutting. Triangle pressure supplies the original yard's wind hinge torque. Native and local browser controls passed; [scope and evidence](docs/yard-brace-trial.md) distinguish this rigid-sail model from full cloth/running-rig dynamics.

An opt-in rigid-body trial and the first loaded wheel/line/tiller/rudder mechanism are implemented. The wheel stays by explicit user preference. The first-person trainer now provides deck walking and gaze-relative movement as the test bed for reusable ship mechanics. Hull hydrostatics and steering transmission run independently of APEX's scene; [reuse contracts](docs/reusable-ship-mechanics.md) describe integration and remaining packaging work. See [physics foundation](docs/physics-foundation.md) for input adapters, native/browser evidence and provisional parameters. Do not mark full hydrodynamics, rope/cloth dynamics or VR training complete.

## October 28 construction evidence

The retained ship now has a tested geometry/articulation refit: station-fitted upperworks and decks, aligned collision, traversable quarterdeck/forecastle stairs, hinged original fittings, eight curved cloth/yard assemblies, mast steps, standing rigging and distinct shared materials. See [measured changes, renders and limits](docs/ship-refit.md). Native construction and Spatial QA tests passed locally; PR checks report the exact current build status. Physical Android verification remains pending.

This is partial implementation of the items below, not completion of historical authentication, globally manifold assembled topology, dynamic cloth/ropes, fracture, hydrostatics or whole-ship access. In particular, the closed geometric reference envelope is not the prototype's current displacement/mass model.

## A. Audit of existing prototype (as of Oct 27, 2026)
- [x] Imported pinnace visual model exists; 288 mesh objects restored by CI. Not verified as historically correct or manifold.
- [x] Procedural hull, deck, mast collision primitives exist. **These are not plank-by-plank geometry or leak-tight boundaries.**
- [x] Three simulated flooding compartments, leak/patch/pump functions, reduced freeboard and speed with water mass (simplified). It is not yet true volumetric buoyancy.
- [x] Working prototype steering command changes rudder angle and controlled ship heading. **Wheel is currently animation driven by rudder input, not connected by actual tiller ropes/pulleys.**
- [x] Animated rudder, yards, door and hatch proxies exist. Imported ship parts are not guaranteed to track them.
- [x] Eight-wave GPU water and CPU sampled height exist. Visual and hydrostatic equivalence not yet validated.
- [ ] Full playable mechanism validation: helm wheel→drum→tiller ropes→quadrant/tiller→rudder→hydrodynamic force→ship yaw.
- [ ] Physically accurate floating, righting moment, mass distribution, free surface effect, capsize.

## B. Full ship construction — build in dependency order
### 1. Reference ship & dimensions
- [ ] Choose one actual historically documented vessel class, date, sail plan, beam, draft, displacement and deck plan. Avoid mixing pinnace eras.
- [ ] Obtain authoritative lines plan: half-breadth, sheer, body stations, sheer/deck camber and keel curvature; establish units and center of gravity.
- [ ] Record material properties of oak/pine/iron/hemp/canvas and controlled approximations; define stress/strain/failure ranges.

### 2. Watertight hull topology
- [ ] Generate closed, manifold outer hull shell with correct sternpost, stem, keel, garboards, strakes, transom/round stern, sheer, deck seams.
- [ ] Create backbone, keelson, floors, ribs/frames, beams, knees, stringers, wales, bulkheads and deck planks; ensure connection IDs.
- [ ] Guarantee nonpenetration along seams at neutral position, and exactly defined breach edges on breakage; automated surface watertightness test.
- [ ] Assign caulking seam integrity and watertight openings (ports, scuppers, hatches); only submerged open connections admit water.
- [ ] Generate walkable interior collision matching the actual geometry; test continuous walk routes, stair clearances and hatch openings.

### 3. Structural graph & fractures
- [ ] Each member has geometry, density/mass, strength, material, damage thresholds, connection sockets and render/collision LOD.
- [ ] Structural graph connects planks to frames to keel/deck beams; implement fastener groups (treenails, bolts, iron fittings).
- [ ] When a connection breaks, remove it and detach the resulting island as a rigid-body chunk; do **not** use hundreds of continually active plank rigid bodies on mobile.
- [ ] Impacts distribute load, crack/tear structures, open damage apertures and create debris with mass conservation.
- [ ] Mast/yard failure propagates through stays, shrouds, mast steps and cross-bracing.

### 4. Hydrostatics and flooding
- [ ] Compute immersed volume of **closed displaced hull** and center of buoyancy across heel, trim and draft; F_b = rho_water g V_submerged.
- [ ] Compute center of mass, righting arm GZ and metacentric restoring behavior; account for cargo and water ballast.
- [ ] Dynamic compartment flow via opening area, waterline head, connected interiors, air escape, and free-surface stability.
- [ ] Multiple hull probe / voxel hydrostatics compared to reference analytical cases; vessel settles or capsizes, never teleports.
- [ ] Damage and pumping affect heel, pitch, acceleration, draft, capsize and sink.

### 5. Sails, spars, rigging and propulsion
- [ ] Mesh sails as fabric thickness and stitched panels (rendered with two-sided cloth shading or thin shell); no rectangular solid stand-ins.
- [ ] Mast segments, yards, boom/gaf, blocks, sheaves, cleats, belaying pins, tackles, sheets, braces, halyards, reef points, shrouds/stays.
- [ ] Wind apparent velocity, lift/drag polar coefficients by angle of attack, luffing, sail shadowing and reefing; transfer forces to rig attachment points.
- [ ] Rope tension/slack, payout and pulley advantage, wear/cut failures. Simulation LOD for Android.
- [ ] Sail cloth billows/furls under wind; test collision/pinning and expected forces at points of sail.

### 6. Helm and rudder mechanical loop
- [ ] Wheel geometry, axle/drum, tiller ropes, running blocks, quadrant/tiller, gudgeons/pintles, blade and hard stops.
- [ ] Wheel movement winds lines; line tension rotates rudder; flow across rudder produces lateral hydrodynamic force and yaw torque. **Partial implementation (Oct 27, 2026): wheel/drum/rope displacement and rudder angle feed a water-speed-dependent lift force; yaw torque integrated through estimated inertia. Rope stiffness, pulley geometry, full 6-DOF dynamics and visual validation pending.**
- [ ] Loss of tiller rope or broken rudder disables or degrades steering. Ship heading never set directly by wheel input. **Partial implementation: test ROPE CUT toggles steering transmission; old direct heading command removed; needs dynamic test and browser visual verification.**

### 7. Working spaces and onboard systems
- [ ] Forecastle/quarterdeck, companionway, orlop/hold, cabins, gun deck (if appropriate), crew stations, ballast, bilge and pumps.
- [ ] Interactable hinges/latches for hatches and doors, capstan, anchor cable, windlass, mooring gear.
- [ ] Crew walking, hand positions and tasks align with real ship fittings. Colliders have no invisible barriers or fall-through gaps.

### 8. Visuals and performance
- [ ] Real wood/rope/iron/canvas material textures with normal/roughness detail; no untextured placeholders.
- [ ] Visible sun, realistic sky, ocean wave groups with proper refraction/specular/foam and wake.
- [ ] LOD/batching/sleeping dynamic debris, mobile constraints and collision layers; target stable 30+ FPS on target Android.
- [ ] Automated Godot startup, CPU physics assertions, browser screenshots, image analysis and touch-control checks.
- [ ] Regression run: helm, gusts, reefing, grounding, collisions, hole, flooding, pumping, capsize, rigging break, repaired sailing.

## C. Next vertical slice — specific pass/fail before scaling up
- [ ] **Helm slice:** Move wheel 90° → cord payout & tiller angle change → measured rudder angle → ship yaws with finite speed; sever rope → wheel no longer steers. Track values in HUD and capture screenshots.
- [ ] **Hull slice:** Build a 2–3-frame watertight hull section with fastening graph, one plank that detaches after impact, actual submerged hole and water ingress; verify no ingress before the opening.
- [ ] **Full boat:** Integrate proven slices into the scene, remove legacy direct-heading control, check Android build and visually inspect all angles.

## Architecture choice
Use a **hybrid simulation**: intact vessel = compound connected assembly with aggregated mass/inertia and hydrostatic sampling; breakable structural graph = detachable bodies only when fractured; ropes = tensioned segments at controllable LOD; sails = deformable render mesh plus aerodynamic force surface. The current script's `freeze=true`, speed interpolation, and direct `rotation` assignment are a **temporary prototype**, NOT a real force-based vessel.

## Research note
The Royal Museums Greenwich ship-plans collection documents the three orthographic views needed to reconstruct hull shape: profile, half-breadth and body plan. Source: https://www.rmg.co.uk/collections/our-collections-ship-plans-collection. Historical reconstruction must use an era-matched actual vessel plan, not approximate rectangular collision hulls. Godot Generic6DOFJoint3D can constrain linked moving rigid bodies, while SoftBody3D supports deformable simulation; both must be benchmarked in WebGL / Android before adoption.

## Technical sources
- Godot 3D joints and constraints: https://docs.godotengine.org/en/latest/classes/class_generic6dofjoint3d.html
- Godot SoftBody3D: https://docs.godotengine.org/en/latest/tutorials/physics/soft_body.html
- Godot RigidBody3D and buoyancy API documentation: https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html
- National Maritime Museum / Royal Museums Greenwich collections: https://www.rmg.co.uk/collections
- Historic ship plans / naval architecture collections: https://www.rmg.co.uk/collections/ship-plans

**Do not mark any untested project tasks complete.** Revisit this checklist after every functional integration and attach commit, automated test and frame evidence.
