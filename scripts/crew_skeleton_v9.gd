extends Node3D
## Real Skeleton3D with articulated bone hierarchy and attached volumetric limbs.
## Bone attachments, not a skinned imported character: upgrade pending.
var skeleton: Skeleton3D
var phase := 0.0
var limb_bones := {}
func _ready() -> void:
 skeleton = Skeleton3D.new()
 add_child(skeleton)
 var spec = [
  ["hips",-1,Vector3(0,.94,0)], ["spine",0,Vector3(0,.3,0)],
  ["head",1,Vector3(0,.51,0)], ["left_arm",1,Vector3(-.3,.33,0)],
  ["right_arm",1,Vector3(.3,.33,0)], ["left_leg",0,Vector3(-.16,-.47,0)],
  ["right_leg",0,Vector3(.16,-.47,0)]]
 for b in spec:
  var index: int = skeleton.get_bone_count()
  skeleton.add_bone(b[0])
  if b[1] >= 0: skeleton.set_bone_parent(index,b[1])
  skeleton.set_bone_rest(index,Transform3D(Basis(),b[2]))
  limb_bones[b[0]] = index
 for name in ["hips","spine","head","left_arm","right_arm","left_leg","right_leg"]:
  var attach := BoneAttachment3D.new()
  attach.bone_name = name
  skeleton.add_child(attach)
  var mesh := MeshInstance3D.new()
  var capsule := CapsuleMesh.new()
  capsule.radius = .11 if "arm" in name else (.15 if "leg" in name else .22)
  capsule.height = .62 if "leg" in name else (.52 if "arm" in name else .36)
  mesh.mesh = capsule
  attach.add_child(mesh)
func _process(delta: float) -> void:
 phase += delta * 4.0
 var amount := .32 if get_parent() is CharacterBody3D and get_parent().velocity.length() > .5 else .03
 for name in ["left_leg","right_leg","left_arm","right_arm"]:
  var sign := 1.0 if name.begins_with("left") else -1.0
  if "arm" in name: sign *= -1.0
  var bone: int = limb_bones[name]
  skeleton.set_bone_pose_rotation(bone,Quaternion(Vector3.RIGHT,sin(phase)*amount*sign))
