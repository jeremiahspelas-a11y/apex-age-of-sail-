extends RefCounted
## First force-transfer approximation: intact fixed rig -> hull reaction at each sail CP.
## Seven pressure-only sails and optional lower-fore membrane support reaction.
const AIR_DENSITY := 1.225
const PressureSurface = preload("res://scripts/sail_pressure_surface.gd")
var vessel: Node3D
var mechanisms: Node
var panels: Array[Dictionary] = []
var last_sail_loads: Array[Dictionary] = []
func bind(rig: Node) -> void:
 mechanisms = rig
 vessel = rig.vessel
 panels.clear()
 for sail: MeshInstance3D in rig.rig_sails:
  var bounds: AABB = sail.get_meta("original_sail_bounds")
  var head_z: float = sail.get_parent().get_meta("rest_socket").z
  var panel := {"mesh":sail,"area":bounds.size.x*bounds.size.y*0.94,"center":Vector3(0,bounds.end.y-bounds.size.y*0.5,head_z-0.50)}
  if sail.get_meta("loaded_brace",false):
   var surface := PressureSurface.new()
   surface.build(sail.mesh.get_faces())
   panel["surface"] = surface
  panels.append(panel)
func evaluate(com: Vector3,wind: Vector3,linear: Vector3,angular: Vector3,reef: float,physics_pose: Variant = null,cloth_load: Dictionary = {}) -> Dictionary:
 var body_pose: Transform3D = vessel.global_transform if physics_pose == null else physics_pose
 var force := Vector3.ZERO
 var torque := Vector3.ZERO
 var brace_torque := 0.0
 last_sail_loads.clear()
 for panel: Dictionary in panels:
  var mesh: MeshInstance3D = panel.mesh
  var local := vessel.global_transform.affine_inverse()*mesh.global_transform
  if panel.has("surface") and not cloth_load.is_empty():
   force += cloth_load.force
   torque += cloth_load.torque
   brace_torque = cloth_load.top_torque.dot(body_pose.basis.y.normalized())
   last_sail_loads.append({"name":mesh.name,"force":cloth_load.wind_force,"support_force":cloth_load.force,"area_m2":mechanisms.cloth.area,"hinge_torque_nm":brace_torque})
   continue
  if panel.has("surface"):
   var pivot: Node3D = mesh.get_parent()
   var hinge: Vector3 = body_pose*(vessel.global_transform.affine_inverse()*pivot.global_position)
   var axis := body_pose.basis.y.normalized()
   var relative: Vector3 = axis*mechanisms.brace.angular_velocity if vessel.force_trial else Vector3.ZERO
   var load: Dictionary = panel.surface.evaluate(body_pose*local,com,wind,linear,angular,reef,hinge,relative)
   force += load.force
   torque += load.torque
   brace_torque = load.hinge_torque.dot(axis)
   last_sail_loads.append({"name":mesh.name,"force":load.force,"area_m2":panel.surface.area,"point":hinge,"hinge_torque_nm":brace_torque})
   continue
  var point: Vector3 = body_pose*local*panel.center
  var normal := (body_pose.basis*local.basis.z).normalized()
  var apparent := wind-linear-angular.cross(point-com)
  var speed := apparent.dot(normal)
  var pressure := 0.5*AIR_DENSITY*speed*absf(speed)*0.8
  var load: Vector3 = normal*pressure*panel.area*clampf(reef,0.0,1.0)
  force += load
  torque += (point-com).cross(load)
  last_sail_loads.append({"name":mesh.name,"force":load,"pressure_pa":pressure,"area_m2":panel.area,"point":point})
 return {"force":force,"torque":torque,"brace_torque":brace_torque}
