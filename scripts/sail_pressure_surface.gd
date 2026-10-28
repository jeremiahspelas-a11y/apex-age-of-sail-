extends RefCounted
## Rigid cambered sail panels: two-sided normal pressure, not a cloth/airflow solver.
## No nodes/assets; caller supplies body/hinge motion and triangle geometry.
var panels: Array[Dictionary] = []
var area := 0.0
var density := 1.225
var coefficient := 0.8

func build(faces: PackedVector3Array) -> void:
 panels.clear()
 area = 0.0
 for i in range(0,faces.size(),3):
  var cross_product := (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i])
  var size := cross_product.length()*0.5
  if size <= 0.000001: continue
  panels.append({"center":(faces[i]+faces[i+1]+faces[i+2])/3.0,"normal":cross_product.normalized(),"area":size})
  area += size

func evaluate(pose: Transform3D,com: Vector3,wind: Vector3,linear: Vector3,angular: Vector3,effective_area: float,hinge: Vector3,relative_angular: Vector3 = Vector3.ZERO) -> Dictionary:
 var force := Vector3.ZERO
 var torque := Vector3.ZERO
 var hinge_torque := Vector3.ZERO
 for panel: Dictionary in panels:
  var point: Vector3 = pose*panel.center
  var normal: Vector3 = (pose.basis*panel.normal).normalized()
  var apparent := wind-linear-angular.cross(point-com)-relative_angular.cross(point-hinge)
  var speed := apparent.dot(normal)
  var load: Vector3 = normal*(0.5*density*coefficient*speed*absf(speed)*panel.area*clampf(effective_area,0.0,1.0))
  force += load
  torque += (point-com).cross(load)
  hinge_torque += (point-hinge).cross(load)
 return {"force":force,"torque":torque,"hinge_torque":hinge_torque}
