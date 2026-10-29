# Loaded lower-foreyard brace trial

**Update, October 29:** the lower fore sail now uses a [deforming membrane and two clew sheets](sail-membrane-trial.md). The rigid triangle-pressure description below records the preceding brace milestone; the current force loop uses membrane top-edge reactions for this yard. Seven other sails remain pressure-only. The 250 kg·m² yard inertia is provisional and excludes the separately integrated membrane.

One existing sail/yard assembly (`YardRig_1_3`, the lower foreyard in this model) now rotates under pressure, rope tension and inertia in PHYSICS TRIAL. It keeps its original mesh, span and mast socket. The other seven yards retain their earlier kinematic trim. This is a bounded mechanical training example, not a claim of complete running rigging or authenticated vessel dimensions.

## Operate it

1. Enter **PHYSICS TRIAL**. The foreyard starts with two pre-tensioned, belayed braces. The six new controls appear below the trial button.
2. The **PORT BRACE / STBD BRACE** button selects a line. Select starboard and press **FREE** to let the opposing line run.
3. Select port and hold **HAUL**. Its available length decreases under bounded crew effort, rotating the yard through tension. **EASE** feeds out the selected line. Releasing either button leaves a finite-effort hand hold; a load above that effort can slip through the hand.
4. Press **BELAY** to fix the selected available line length. A belayed line can still go slack and stretch; belaying does not impose a yard angle. Attend the opposite brace to remove unwanted slack. The display reports yard angle, both tensions, selected-line mode and available length.
5. **FREE** removes the hand restraint. **CUT BRACE** removes that line's transmitted force and rendered connection. Leave and re-enter PHYSICS TRIAL to reset the two lines. Fly inspection, hiding the HUD and focus loss stop held hauling/easing commands.

The model has fixed turning blocks lashed near the mainmast and deck-supported belaying pins. Each brace runs from a foreyard arm through its fixed block to its pin. This is a single-part lead with no mechanical purchase. Rendered slack uses a display curve, not rope segments with collision.

## Model and coupling

`yard_brace.gd` is a scene-independent `RefCounted`. `configure(half_span, leads, belays, initial_angle)` takes two block and pin positions relative to the yard hinge. Angles are radians and all dimensions/loads use SI units. `step(dt, wind_hinge_torque)` advances the yard and free-end coordinates with eight substeps and returns relative angular acceleration plus yard/block/pin reaction vectors.

For a line, geometric length is the moving yard-to-block span plus the fixed block-to-pin span. Positive extension produces a spring/damper tension; slack and cut lines transmit no force. Virtual work gives yard torque `−T dL/dθ`. A hand-controlled tail targets ±0.35 m/s (or zero for holding), with effort capped at 180 N per line. If the load exceeds the cap, payout follows the force balance. A free tail runs under line tension, while an ideal belaying pin fixes its available length. Exhausting the configured tail reserve lets the end run out instead of becoming an invisible stopper.

Defaults are provisional: 250 kg·m² yard/sail yaw inertia, 1,500 N/m effective rope stiffness, 45 N·s/m line damping, 2 kg effective free-end mass, 80 N initial tension, 45 N·m·s bearing damping and ±55° yard stops. These are stability/interaction parameters, not measured hemp or vessel data. Belaying and cutting dissipate unresolved line energy; they do not model knot friction, failure or recoil.

`sail_pressure_surface.gd` samples the 384 triangles of this sail's existing cambered mesh. Each triangle receives two-sided normal pressure from local apparent wind, including hull and relative yard velocity. It returns resultant force, moment about the hull COM and moment about the yard hinge. Backwinding reverses the pressure sign. This is a rigid curved pressure surface; neither dynamic cloth nor resolved airflow is implemented, and GPU flutter does not alter the sampled geometry.

The vessel integration applies wind force/moment once. It subtracts the relative yard's angular-inertia reaction from hull torque, as with the steering mechanism. Routed internal line reactions sum to zero force and moment across the assembled system; applying those again as external forces would double-count them. Gyroscopic/cross-axis inertia effects, changing mass distribution, line weight, moving-block purchase, block friction, collision and sail-clew sheet constraints remain outside this slice.

## Evidence

`tests/yard_brace_test.gd` verifies analytical flat-panel force, backwinding, pressure dissipation including relative yard motion, hauling/easing, bounded effort and overloaded-hand slip, belayed length under wind load, free payout, cutting, stored-energy decay, 60/120 Hz convergence, and balanced yard/block/pin reactions. Its actual vessel integration turns the original foreyard about 14.75° under differential line control with a measured wind hinge load near −181 N·m. Existing construction, force, first-person and Spatial QA suites pass locally.

Local Chromium at a 960×540 Pixel 7 viewport ran the real buttons: release starboard, haul port, then belay. The control log recorded a change from −0.06° to 6.87° at belaying, fixed port mode and changed available length, with no page/console errors. Browser CI repeats that action sequence and saves the control log and rendered screenshot. This is emulation; physical Android and VR acceptance remain pending.

## Reference boundary

[The Queen Anne's Revenge conservation project](https://www.qaronline.org/blog/2017-10-26/sailing-a-ship) distinguishes setting sheets/halyards from adjusting yards through braces. [Nares's 1877 seamanship manual](https://whalesite.org/anthology/1877_Nares_Seamanship.htm) describes yard-arm brace fittings and attending opposing braces while trimming. These support the mechanism's purpose, not the provisional route, coefficients or seventeenth-century dimensions used here. Godot's [direct body state API](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html) supplies the force/torque integration interface.
