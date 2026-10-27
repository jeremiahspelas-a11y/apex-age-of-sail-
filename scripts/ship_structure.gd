extends Node3D
## Convex compound collision volumes; walkable decks with central hatch gaps.
@onready var boat: RigidBody3D = get_parent() as RigidBody3D
func _ready() -> void:
 add_box("Keel",Vector3(1.0,0.8,23.0),Vector3(0,-1.8,0))
 for side in [-1.0,1.0]:
  add_box("HullSide",Vector3(.55,2.5,20.0),Vector3(side*2.6,-.5,0))
  add_box("Bulwark",Vector3(.25,1.1,18.0),Vector3(side*2.85,1.05,0))
  add_box("DeckWing",Vector3(2.05,.2,19.8),Vector3(side*1.73,.35,0))
  add_box("LowerDeckWing",Vector3(2.05,.2,17.0),Vector3(side*1.73,-1.5,0))
 for entry in [[-8.3,3.6],[-1.0,4.0],[6.0,7.2]]:
  var z: float = entry[0]
  var length: float = entry[1]
  add_box("DeckCenter",Vector3(1.4,.2,length),Vector3(0,.35,z))
 for entry in [[-6.7,3.2],[-1.0,3.6],[5.4,5.0]]:
  var z: float = entry[0]
  var length: float = entry[1]
  add_box("LowerCenter",Vector3(1.4,.2,length),Vector3(0,-1.5,z))
 add_box("Quarterdeck",Vector3(4.8,.25,5.2),Vector3(0,1.5,9))
 add_box("Forecastle",Vector3(3.8,.25,2.9),Vector3(0,1.2,-10))
 for z in [-4.0,2.0]:
  var ramp := CollisionShape3D.new()
  var box := BoxShape3D.new()
  box.size=Vector3(1.0,.16,3.5)
  ramp.shape=box
  ramp.position=Vector3(0,-.5,z+1.1)
  ramp.rotation.x=-.43
  boat.add_child.call_deferred(ramp)
 for z in [-5.5,1.2,8.0]:
  var shape := CylinderShape3D.new()
  shape.radius=.34
  shape.height=9.0
  add_shape("Mast",shape,Vector3(0,5,z))
 # Construction pass 1: coherent ship-interior frame, beam and keelson skeleton.
 # Visual members belong to the vessel transform rather than world-space decoration.
 build_timber_skeleton()

func build_timber_skeleton() -> void:
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(0.39,0.23,0.12)
 material.roughness = 0.93
 # Longitudinal keelson mechanically locates the floor timbers.
 add_timber("Keelson", Vector3(0.54,0.44,21.0), Vector3(0,-1.26,0),material)
 # Eleven transverse timber stations: paired uprights, floor timbers and deck beams.
 # They are deliberately below the imported sail/rigging geometry.
 for station in 11:
  var z: float = -9.5 + float(station)*1.9
  add_timber("Floor_%02d" % station,Vector3(4.3,0.24,0.21),Vector3(0,-1.2,z),material)
  for side in [-1,1]:
   add_timber("Frame_%02d_%s" % [station,"P" if side < 0 else "S"],Vector3(0.24,1.62,0.23),Vector3(float(side)*2.15,-0.31,z),material)
  add_timber("DeckBeam_%02d" % station,Vector3(4.45,0.23,0.24),Vector3(0,0.32,z),material)
 for side in [-1,1]:
  add_timber("Stringer_%s" % ["P" if side < 0 else "S"],Vector3(0.2,0.22,20.0),Vector3(float(side)*2.18,-0.46,0),material)

func add_timber(n:String,size:Vector3,pos:Vector3,mat:Material) -> void:
 var member := MeshInstance3D.new()
 member.name = n
 var timber := BoxMesh.new()
 timber.size = size
 member.mesh = timber
 member.material_override = mat
 member.position = pos
 add_child(member)

func add_box(n:String,size:Vector3,pos:Vector3) -> void:
 var shape := BoxShape3D.new()
 shape.size=size
 add_shape(n,shape,pos)
func add_shape(n:String,shape:Shape3D,pos:Vector3) -> void:
 var collision := CollisionShape3D.new()
 collision.name=n+"Collider"
 collision.shape=shape
 collision.position=pos
 boat.add_child.call_deferred(collision)
