extends SceneTree
## Measurement only: isolated coarse canvas, cut sheets, gravity, no collision.
## This is not a material/reference or whole-sail acceptance test.
const Membrane = preload("res://scripts/sail_membrane.gd")
func _initialize() -> void:
 var cloth := Membrane.new()
 var leads: Array[Vector3] = [Vector3(-2.6,-4,3),Vector3(2.6,-4,3)]
 var pins: Array[Vector3] = [Vector3(-2.4,-4.5,3.3),Vector3(2.4,-4.5,3.3)]
 cloth.configure(AABB(Vector3(-2.75,-2.8,0),Vector3(5.5,2.8,0.1)),0,Transform3D.IDENTITY,leads,pins)
 cloth.cut(0)
 cloth.cut(1)
 for tick in 900:
  cloth.step(1.0/60,Transform3D.IDENTITY,Vector3.ZERO,1,Vector3.ZERO,Vector3.ZERO)
  if tick in [0,59,179,899]:
   var kinetic := 0.0
   var depth := 0.0
   for i in cloth.points.size():
    kinetic += 0.5*cloth.masses[i]*cloth.velocities[i].length_squared()
    depth = maxf(depth,absf(cloth.points[i].z))
   print("CALM GRAVITY PROBE ",JSON.stringify({"seconds":float(tick+1)/60,"max_depth_m":depth,"kinetic_j":kinetic,"clew":str(cloth.points[28]),"center":str(cloth.points[17])}))
 quit()
