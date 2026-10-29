# Reusable ship mechanics

The first-person trainer is the integration scene for mechanics that can later become a shareable complete ship. Keep vessel simulation separate from the player, lessons, cameras and platform input. The current standalone components are Godot GDScript; another engine would need a port of these numerical models.

## Current boundaries

| Component | Caller supplies | Component produces | Dependencies |
|---|---|---|---|
| `hull_hydrostatics.gd` | Hull sections/bounds, rigid pose, water heights, COM and velocities | Displaced volume, buoyancy and water resistance with moments | Godot math/RefCounted |
| `steering_transmission.gd` | Geometry/configuration, fixed time step, helm effort or crew target, water hinge torque | Wheel/rudder angles and velocities, line tensions, angular accelerations | Godot math/RefCounted |
| `yard_brace.gd` | Yard span, block/pin locations, fixed time step, wind hinge torque, hand/belay commands | Yard and tail state, tensions and balanced attachment reactions | Godot math/RefCounted |
| `sail_membrane.gd` | Mesh/fixture geometry, moving poses, wind, COM and line commands | Deformed cloth, sheet tensions and support reactions from momentum balance | Godot math/RefCounted, optional ArrayMesh output |
| `sail_pressure_surface.gd` | Triangle geometry, wind and rigid/relative hinge motion | Panel pressure resultant and moments about COM and hinge | Godot math/RefCounted |
| `sea_spectrum.gd` | Seed, position, time and sea amplitude | Displacement, height, normal, compression and water velocity | Godot math/RefCounted |
| `weather_field.gd` | Seed, position, time and optional scenario | Wind, gust/front effects, cloud/rain/visibility/pressure/temperature | Godot noise/RefCounted |
| `vr_hand_input.gd` | Hand positions and current wheel state | Bounded torque or haul/ease command | Godot math/RefCounted |
| `crew_session.gd`, `vr_sailing.gd` | Host/client transport or WebXR tracking | Authority/replication or tracked-input adapters | Current trainer scene |
| `rig_pressure_load.gd` | Bound sail meshes, wind, body state, effective sail area | Per-sail pressure loads and resultant force/moment | Current sail scene adapter |
| `sailing_physics.gd` | Ocean, wind, mass, compartments and mechanism adapter | Forces applied to Godot's rigid body | APEX vessel integration |
| `ship_mechanisms_v9.gd` | Imported sockets/meshes, steering state and trim | Visible machinery, openings and rig articulation | Current pinnace geometry |
| `sea_trial.gd`, `player_walk.gd` | Keyboard/touch, player and view | Desktop/touch deck experience and inspection | Trainer UI and scene |

## Hull solver

Copy `scripts/hull_hydrostatics.gd` into another Godot project. It has no preloads or scene references. Build once with `build_from_sections(section_at, bounds, nx, nz)`. The callback returns a `PackedVector3Array` of ordered closed-section vertices at body-local longitudinal coordinate `z`; closure is implicit. Sections must be convex or have one continuous filled vertical interval for each sampled `x`. Bounds must enclose those sections. Use meters and an unscaled rigid transform.

```gdscript
const Hydro = preload("res://scripts/hull_hydrostatics.gd")
var hydro := Hydro.new()

func section_at(z: float) -> PackedVector3Array:
 return PackedVector3Array([
  Vector3(-2,-1,z), Vector3(2,-1,z),
  Vector3(2,1,z), Vector3(-2,1,z)])

func prepare_hull() -> void:
 hydro.build_from_sections(section_at,AABB(Vector3(-2,-1,-4),Vector3(4,2,8)))

func calm_water(_x: float,_z: float) -> float:
 return 0.0

# In a RigidBody3D adapter's _integrate_forces(state):
# var load = hydro.evaluate(state.transform,calm_water,center_of_mass,
#                          state.linear_velocity,state.angular_velocity)
# state.apply_central_force(load.buoyancy+load.drag)
# state.apply_torque(load.buoyancy_torque+load.drag_torque)
```

All returned vectors are in world coordinates; moments are about the supplied body-local COM transformed into world space. Godot supplies gravity separately; do not add gravity again. Water uses a world-space `(x,z) → height` callback, sea-water density 1,025 kg/m³ and gravity 9.8 m/s². Match the host world's gravity. The optional sixth argument to `evaluate` is `(x,z) → Vector3` water velocity; resistance then uses relative flow from a sampled/interpolated grid. Resistance rates are empirical and configurable. This approximation does not resolve slamming, overhangs or entrapped air. `equilibrium_height(mass_kg)` finds flat-water equilibrium for an upright, unsaturated hull; it is a setup helper, not a motion controller.

## Steering solver

Copy `scripts/steering_transmission.gd`. Each instance owns its state and can run without a scene tree:

```gdscript
const Steering = preload("res://scripts/steering_transmission.gd")
var helm := Steering.new()

func physics_step(dt: float,hand_torque_nm: float,water_hinge_torque_nm: float) -> void:
 helm.set_helm_torque(hand_torque_nm)
 var reaction := helm.step(dt,water_hinge_torque_nm)
 # Read helm.wheel_angle, helm.rudder_angle, and both line tensions.
 # Apply visible rotations and the opposing angular-inertia reaction to the hull.
 # reaction contains wheel_acceleration and rudder_acceleration (rad/s²).
```

Angles are radians, angular velocities rad/s, tensions newtons, torque N·m and inertia kg·m². `set_helm_torque(0)` releases a backdrivable wheel; it does not recenter it. Effort is bounded at the configured handle radius by the current 180 N crew limit. `use_button_helm()` switches to a bounded virtual crew servo; then `step(dt, water_torque, normalized_target)` accepts a −1…1 wheel target. `connected = false` removes line transmission. Read `steering_energy()` for a stored-energy diagnostic.

Default geometry has a 1.70 m tiller and two ideal blocks at ±1.10 m abeam of its neutral tip, relative to the rudder hinge. Configure `tiller_length`, `block_half_span`, drum/handle radii, inertia, stops and effective line properties before use. These must remain positive where appropriate. Four substeps run within each fixed physics tick; stability for arbitrary stiffness/time steps is not guaranteed. The current model has massless routing blocks and lumped elastic lines, without purchase, pulley friction or segment collision. `step(..., true)` selects the optional provisional whipstaff model instead of the default wheel.

## Full-ship resource milestones

1. Current foundation: first-person deck walking, independent hull and steering solvers, pressure forces and measured geometry.
2. First loaded brace circuit implemented: [lower foreyard → two braces → blocks → belaying pins](yard-brace-trial.md), with hauling, easing, belaying, free payout and cutting. Next, add sail-clew sheet constraints and dynamic shape/load response; this rigid-yard example does not complete the running rig.
3. Generalize vessel configuration and sail/rig adapters; provide a minimal sample scene independent of APEX's world and UI, with documented sockets and mass budget.
4. Calibrate handling against reference data, add lessons and measurable maneuvers, and validate target hardware. Add tracked VR grip/input as an adapter to the same mechanics.
5. Package a versioned ship resource with example integration, dependency/license inventory and stable interfaces. The repository currently contains the foundation, not that finished release.

## Deforming sail and sheets

The lower fore sail now integrates a standalone XPBD membrane and two unilateral sheets. [Configure/step/render/replication contract, mass accounting, controls and limits](sail-membrane-trial.md) explain how to substitute this circuit into another Godot vessel without double-counting pressure or canvas mass.
