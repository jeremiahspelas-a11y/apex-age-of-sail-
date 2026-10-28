# Force-driven sailing trainer: first functional slice

The goal is a historically inspired, mechanically understandable sailing trainer that can later accept VR hands. The **steering wheel remains the default**, per the user's decision. Exact 1670–1690 reconstruction is secondary to coherent operation. A provisional whipstaff arrangement remains optional (`use_whipstaff`), with the original wheel source retained in either case. This is not yet a complete sailing curriculum or a VR application.

## Try the new mode

The starting view is first person on the walkable deck. Arrow keys/on-screen arrows walk relative to horizontal gaze; right-mouse drag or a right-side touchscreen drag looks around. The camera follows the player's eye position and vessel heading with an upright desktop horizon. FLY / WALK (F) enters inspection and returns to the deck; the player stays aboard during inspection. A/D remain helm commands, W/S effective sail area, and Q/E yard trim. These are trainer input adapters, not simulated hands at each fitting.

In the game, use **PHYSICS TRIAL** below the sailing/damage controls. **RETURN TO PROTOTYPE** restores the earlier controlled mode. A web build also accepts `?simulation=forces`. Entering the trial resets height/velocity once, then Godot's rigid-body solver advances the ship; the trial does not continuously set its position, heel or heading.

The HUD shows buoyancy, total wind load, and port/starboard steering-line tension. Port/Starboard ask a force-limited virtual crew member to turn the wheel. LINK CUT disconnects the steering transmission. The input adapter `Mechanisms.set_helm_torque(torque_nm)` accepts direct wheel torque; zero torque releases it for backdriving. `use_button_helm()` returns to the button-controlled crew. VR grip constraints/controllers and haptics are future work.

## Implemented mechanics

- **Reusable core:** hull section geometry and water sampling enter through callbacks; hull evaluation returns force/moment data. A separate `RefCounted` steering solver owns the wheel/rudder state and accepts explicit torque/command inputs without nodes or assets. The pinnace scene adapters provide geometry, apply loads and render state. See [reuse contracts and examples](reusable-ship-mechanics.md). The complete ship is not yet a packaged drop-in resource.
- **Buoyancy:** 660 retained body-fixed integration columns from a 20×40 sampling grid clip the existing hull volume against a 3×7 sampled sea-height field. Their displaced volumes produce upward forces and moments about the chosen center of mass. The numerical full-volume result is 382.82 m³ versus the triangulated reference's 379.69 m³ (0.83% difference). Real waterline comes from submerged volume, rather than the prototype's fixed height offset.
- **Rigid-body response:** translation, pitch, roll and yaw are released. Forces and moments enter through `_integrate_forces`. Empirical, anisotropic water damping opposes point velocity and is tested to dissipate energy. The existing CPU/GPU wave field is shared; the ocean surface now exposes the height method the boat actually requests.
- **Mass:** the initial 80,000 kg dry mass, center of mass `(0,−0.60,0)` and box-based inertia are explicitly provisional configuration values. Existing compartment water contributes weight and shifts the center of mass. There is no claim these values authenticate a historical vessel.
- **Sail pressure:** all eight existing sail assemblies report individual area, local apparent wind and pressure load. Seven retain their fixed-surface approximation. The lower foreyard uses its cambered mesh's triangle pressure loads, including relative yard motion, and is constrained by two loaded braces. See [brace controls, model and evidence](yard-brace-trial.md). This remains a rigid-sail approximation; GPU flutter and dynamic cloth mechanics are separate.
- **Steering transmission:** the wheel turns a drum and changes the available lengths of two opposing steering lines. Each line has pretension, effective elasticity, damping and a tension-only response. Actual tiller-head geometry determines line lengths and moment arms. Line reaction resists/backdrives the wheel and drives the rudder; four substeps run per physics tick. Broken lines transmit zero tension.
- **Crew and rudder load:** crew wheel torque is bounded by 180 N at the measured 0.72 m handle radius. A local-flow rudder lift/drag approximation produces an external load at the blade (lift is perpendicular to flow; drag dissipates energy); its hinge torque opposes or backdrives steering. Rudder and wheel rotational reactions are returned to the hull, with small gyroscopic terms omitted in this first model.
- **Visible machinery:** the original ring, spokes, hub and added wooden drum turn together. Two rendered lines follow the block route to the moving tiller, showing simple slack when unloaded. Their render curves are not a segment collision/rope-mass solver. The wheel assembly is moved clear of the mizzenmast and its lower rim raised above the quarterdeck, with a fitted pedestal and two small line slots. Original source geometry is retained. Optional whipstaff use opens its own deck slot; the preferred wheel configuration does not leave that slot open.

## Assumptions that still need calibration

The drum radius (0.18 m), tiller length (1.70 m) and handle radius derive from the current fitted geometry. Effective rope stiffness (8,000 N/m), damping (160 N·s/m), pretension (120 N), wheel/rudder inertia (20/200 kg·m²), human effort limit, stops, sail pressure coefficient and hull resistance are provisional. They need reference data and maneuvering comparisons before this is used to teach quantitative handling.

The two lines are lumped elastic elements with massless ideal routing blocks. There is no block friction, purchase, capstan holding model, line collision, structural stress/fracture, true free-surface flooding, air entrapment, wave slamming or resolved airflow yet. Open hatches do not automatically flood through a complete opening graph. The existing breach/patch/pump controls remain simplified. Therefore positive buoyancy and steering response do not establish full seaworthiness or training fidelity.

## Verification

`tests/force_trial_test.gd` checks an analytical half-submerged box (`F = ρgV` and its force center), dry/full immersion, hull grid convergence, displacement-derived equilibrium, added-cargo draft, restoring heel moment, dissipative damping, and an actual engine-driven impulse/recovery test. It also checks individual sail pressure loads, zero wind/reef load, stored steering energy decay, tension-only lines, water-load backdriving, disconnected steering, finite crew effort/stops and the tiller/staff linkage geometry.

The existing ship-construction and Spatial QA regressions remain enabled. Browser CI enters the physical trial, records a finite buoyant physics sample and captures its rendered state. Native and browser tests do not establish physical Android performance, VR comfort or lesson accuracy.

`tests/trainer_test.gd` checks eye position, gaze-relative walking at a nonzero head pitch, grounded collision, player visibility, movement suspension/deck carry during inspection, return to the eye camera, heading/horizon behavior and independent touch ownership. The force test also exercises caller-supplied rectangular hull sections and independent steering instances without the vessel scene.

## Connected running-rig slice and next mechanism

The first pressure-loaded sail/yard → two braces → fixed wooden blocks → belaying pins circuit is implemented and tested. Hauling/easing changes available length; line tension and wind torque determine the lower foreyard angle. Belaying, free payout, cutting, backwinding and balanced reactions have dedicated checks. Full rope/cloth dynamics are still open. The next mechanism is a sail-clew sheet constraint so changing edge tension can affect sail shape and load, before expanding equivalent running rigging across the ship.

## References and the period decision

- [Godot RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html) and [PhysicsDirectBodyState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html): direct force integration and rigid-body state.
- [Royal Museums Greenwich: circa-1703 model with wheel and whipstaff evidence](https://www.rmg.co.uk/collections/objects/rmgc-object-66179): the museum qualifies the wheel's originality; this is not proof that wheels were standard on a 1670–1690 pinnace.
- [Vasa Museum: steering position and whipstaff](https://faq.vasamuseet.se/category/45/article/24517?lang=en): evidence for a seventeenth-century alternative, not dimensions for our smaller vessel.

User decision: retain the wheel and pursue a functioning, historically inspired ship. The museum evidence is context, not a requirement to remove the preferred control.
