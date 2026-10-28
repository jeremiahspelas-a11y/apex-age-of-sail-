extends RefCounted
## First force-transfer approximation: intact fixed rig -> hull reaction at each sail CP.
## Cloth/rope dynamics are not implemented by this pressure-only model.
const AIR_DENSITY := 1.225
var vessel: Node3D
var panels: Array[Dictionary] = []
var last_sail_loads: Array[Dictionary] = []
func bind(mechanisms: Node) -> void:
 vessel = mechanisms.vessel
 panels.clear()
 for sail: MeshInstance3D in mechanisms.rig_sails:
  var bounds: AABB = sail.get_meta("original_sail_bounds")
  var head_z: float = sail.get_parent().get_meta("rest_socket").z
  panels.append({"mesh":sail,"area":bounds.size.x*bounds.size.y*0.94,"center":Vector3(0,bounds.end.y-bounds.size.y*0.5,head_z-0.50)})
func evaluate(com: Vector3,wind: Vector3,linear: Vector3,angular: Vector3,reef: float,physics_pose: Variant = null) -> Dictionary:
 var body_pose: Transform3D = vessel.global_transform if physics_pose == null else physics_pose
 var force := Vector3.ZERO
 var torque := Vector3.ZERO
 last_sail_loads.clear()
 for panel: Dictionary in panels:
  var mesh: MeshInstance3D = panel.mesh
  var local := vessel.global_transform.affine_inverse()*mesh.global_transform
  var point: Vector3 = body_pose*local*panel.center
  var normal := (body_pose.basis*local.basis.z).normalized()
  var apparent := wind-linear-angular.cross(point-com)
  var speed := apparent.dot(normal)
  var pressure := 0.5*AIR_DENSITY*speed*absf(speed)*0.8
  var load: Vector3 = normal*pressure*panel.area*clampf(reef,0.0,1.0)
  force += load
  torque += (point-com).cross(load)
  last_sail_loads.append({"name":mesh.name,"force":load,"pressure_pa":pressure,"area_m2":panel.area,"point":point})
 return {"force":force,"torque":torque}
