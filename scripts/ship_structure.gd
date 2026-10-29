extends Node3D
## Convex compound collision volumes; walkable decks with central hatch gaps.
const Refit = preload("res://scripts/ship_refit.gd")
@onready var boat: RigidBody3D = get_parent() as RigidBody3D
func _ready() -> void:
 Refit.apply(boat)
 _build_walk_surfaces()
 # Colliders retain measured masthead positions and extend down to the keelson step.
 # Foremast z=-6.5 (y center 10.15, height 17.7), mainmast z=3.1
 # (y center 11.65, height 20.7), mizzen z=10.8 (y center 7.65, height 12.7).
 for mast in [[-6.5,10.15,17.7,0.5],[3.1,11.65,20.7,0.5],[10.8,7.65,12.7,0.36]]:
  var shape := CylinderShape3D.new()
  shape.radius = mast[3] * 0.5
  shape.height = mast[1]+mast[2]*0.5-Refit.MAST_STEP_Y
  add_shape("Mast",shape,Vector3(0,Refit.MAST_STEP_Y+shape.height*0.5,mast[0]))
 # Remove the overlapping obsolete fairing-study hull ONLY when the newer
 # V6 closed hull is present. This preserves the original late-period ship rig.
 _audit_original_projection_meshes()
 # Reuse the refitted original frames; add their floor, beam and keelson supports.
 # Visual members belong to the vessel transform rather than world-space decoration.
 build_timber_skeleton()
 # Preserve original GLB exterior; second procedural hull used incorrect shorter dimensions.
 # build_hull_strakes(), build_end_closures(), build_keel_bottom() intentionally not invoked.

func _build_walk_surfaces() -> void:
 # The former 0.45 m deck collider sat 0.68 m below the visible deck.
 var coarse := boat.get_node_or_null("HullCollision") as CollisionShape3D
 if coarse != null: coarse.set_deferred("disabled",true)
 _deck_collision("MainDeck",-13.0,13.2,Refit.MAIN_BOTTOM,Refit.MAIN_TOP,2.95,Refit.HATCHES)
 _deck_collision("Forecastle",-12.9,-8.45,1.84,Refit.FORE_TOP,2.05,[Refit.FORE_STAIR])
 _deck_collision("Quarterdeck",6.7,11.8,2.14,Refit.QUARTER_TOP,2.65,Refit.quarter_openings(boat))
 _deck_collision("LowerDeck",-11.15,9.70,-1.20,-1.07,2.325,[])
 _stair_ramp("QuarterdeckStairs",Vector3(0,Refit.MAIN_TOP,6.2),Vector3(0,Refit.QUARTER_TOP,9.7),1.4)
 _stair_ramp("ForecastleStairs",Vector3(0,Refit.MAIN_TOP,-7.44),Vector3(0,Refit.FORE_TOP,-9.14),1.3)
 add_box("ForecastleLanding",Vector3(1.4,0.16,0.56),Vector3(0,Refit.FORE_TOP-0.08,-9.42))
 for side in [-1.0,1.0]:
  for i in range(Refit.STATIONS.size()-1):
   var a: float = Refit.STATIONS[i]
   var b: float = Refit.STATIONS[i+1]
   var points := PackedVector3Array()
   for z in [a,b]:
    var x: float = side*Refit.deck_width(z)
    for xx in [x,x-side*0.16]:
     points.append(Vector3(xx,-1.30,z))
     points.append(Vector3(xx,Refit.rail_deck(z)+0.68,z))
   var shape := ConvexPolygonShape3D.new()
   shape.points = points
   add_shape("Bulwark_%s_%d"%[str(side),i],shape,Vector3.ZERO)

func _deck_collision(label: String,start: float,end: float,bottom: float,top: float,limit: float,holes: Array) -> void:
 var index := 0
 for cell: Dictionary in Refit.deck_cells(start,end,limit,holes,bottom):
  var points := PackedVector3Array()
  for y in [bottom,top]:
   points.append_array(PackedVector3Array([Vector3(cell.l0,y,cell.z0),Vector3(cell.r0,y,cell.z0),Vector3(cell.l1,y,cell.z1),Vector3(cell.r1,y,cell.z1)]))
  var shape := ConvexPolygonShape3D.new()
  shape.points = points
  add_shape(label+str(index),shape,Vector3.ZERO)
  index += 1

func _stair_ramp(label: String,start: Vector3,end: Vector3,width: float) -> void:
 var collision := CollisionShape3D.new()
 collision.name = label+"Collider"
 var shape := BoxShape3D.new()
 shape.size = Vector3(width,0.10,start.distance_to(end))
 collision.shape = shape
 collision.position = (start+end)*0.5-Vector3(0,0.05,0)
 collision.rotation.x = -atan2(end.y-start.y,end.z-start.z)
 boat.add_child.call_deferred(collision)

func build_timber_skeleton() -> void:
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(0.39,0.23,0.12)
 material.roughness = 0.93
 # Longitudinal keelson mechanically locates the floor timbers.
 add_timber("Keelson", Vector3(0.54,0.44,21.0), Vector3(0,-1.26,0),material)
 # Station curves use half-beam and vertical sheer profiles instead of straight box frames.
 # This is a procedural hull-shape prototype, NOT a surveyed historical lines plan.
 for station in 11:
  var z: float = -9.5 + float(station)*1.9
  var beam: float = Refit.deck_width(z)-0.20
  var deck_y: float = Refit.MAIN_BOTTOM-0.12
  add_timber("Floor_%02d" % station,Vector3(beam*1.8,0.24,0.21),Vector3(0,-1.2,z),material)
  var hatch_half := 0.0
  for opening: Rect2 in Refit.HATCHES:
   if z > opening.position.y-0.12 and z < opening.end.y+0.12:
    hatch_half = maxf(hatch_half,opening.size.x*0.5+0.10)
  if hatch_half > 0.0:
   var length := beam*0.99-hatch_half
   for side in [-1.0,1.0]:
    add_timber("HatchDeckBeam_%02d_%s"%[station,str(side)],Vector3(length,0.23,0.24),Vector3(side*(hatch_half+length*0.5),deck_y,z),material)
  else:
   add_timber("DeckBeam_%02d"%station,Vector3(beam*1.98,0.23,0.24),Vector3(0,deck_y,z),material)

 for side in [-1,1]:
  add_timber("Stringer_%s" % ["P" if side < 0 else "S"],Vector3(0.2,0.22,20.0),Vector3(float(side)*2.18,-0.46,0),material)

func hull_station(z: float, side: float, height_fraction: float) -> Vector3:
 # Provisional fairing curve. Final shape must come from surveyed hull lines.
 var taper: float = pow(absf(z)/11.5,1.5)
 var beam: float = 2.22 * (1.0-0.38*taper)
 var deck_y: float = 0.32+0.22*taper
 var t: float = clampf(height_fraction,0.0,1.0)
 return Vector3(side*beam*(0.35+0.65*sin(t*PI*0.5)),lerpf(-1.35,deck_y,t),z)

func build_hull_strakes() -> void:
 # Continuous, double-sided outer planking panels follow the same station curve as the ribs.
 # Panels are individually named so future fasteners/damage can address a single strake.
 var plank_mat := StandardMaterial3D.new()
 plank_mat.albedo_color = Color(0.37,0.20,0.105)
 plank_mat.roughness = 0.89
 plank_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 for side in [-1,1]:
  for band in 8:
   var verts := PackedVector3Array()
   var norms := PackedVector3Array()
   var uvs := PackedVector2Array()
   var idx := PackedInt32Array()
   for station in 25:
    var z: float = lerpf(-10.9,10.9,float(station)/24.0)
    for edge in 2:
     var t: float = float(band+edge)/8.0
     verts.append(hull_station(z,float(side),t))
     uvs.append(Vector2(float(station)/24.0*4.0,t*8.0))
     norms.append(Vector3(float(side),0,0))
   for station in 24:
    var k: int = station*2
    if side > 0:
     idx.append_array(PackedInt32Array([k,k+2,k+1,k+1,k+2,k+3]))
    else:
     idx.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
   var arrays := []
   arrays.resize(Mesh.ARRAY_MAX)
   arrays[Mesh.ARRAY_VERTEX] = verts
   arrays[Mesh.ARRAY_NORMAL] = norms
   arrays[Mesh.ARRAY_TEX_UV] = uvs
   arrays[Mesh.ARRAY_INDEX] = idx
   var mesh := ArrayMesh.new()
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var plank := MeshInstance3D.new()
   plank.name = "HullStrake_%s_%02d" % ["P" if side < 0 else "S",band]
   plank.mesh = mesh
   plank.material_override = plank_mat
   add_child(plank)

func build_end_closures() -> void:
 # Cap the provisional planked hull at bow and stern, avoiding open side-profile ends.
 # This does not yet establish a certified watertight manifold.
 var end_mat := StandardMaterial3D.new()
 end_mat.albedo_color = Color(0.37,0.20,0.105)
 end_mat.roughness = 0.89
 end_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 for end_z in [-10.9,10.9]:
  var vertices := PackedVector3Array()
  var indices := PackedInt32Array()
  for band in 9:
   var t: float = float(band)/8.0
   vertices.append(hull_station(float(end_z),-1.0,t))
   vertices.append(hull_station(float(end_z),1.0,t))
  for band in 8:
   var v: int = 2*band
   indices.append_array(PackedInt32Array([v,v+1,v+2,v+1,v+3,v+2]))
  var arrays := []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_INDEX] = indices
  var surface := ArrayMesh.new()
  surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var end_panel := MeshInstance3D.new()
  end_panel.name = "SternClosure" if end_z > 0.0 else "BowClosure"
  end_panel.mesh = surface
  end_panel.material_override = end_mat
  add_child(end_panel)

func build_keel_bottom() -> void:
 # Add the missing lower shell between the two garboard edges at each station.
 # Still an open-top visual shell, not a certified manifold or buoyancy volume.
 var shell_mat := StandardMaterial3D.new()
 shell_mat.albedo_color = Color(0.34,0.19,0.10)
 shell_mat.roughness = 0.91
 shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 var verts := PackedVector3Array()
 var indices := PackedInt32Array()
 for station in 25:
  var z: float = lerpf(-10.9,10.9,float(station)/24.0)
  verts.append(hull_station(z,-1.0,0.0))
  verts.append(Vector3(0,-1.58,z))
  verts.append(hull_station(z,1.0,0.0))
 for station in 24:
  var k: int = station*3
  indices.append_array(PackedInt32Array([k,k+3,k+1,k+1,k+3,k+4]))
  indices.append_array(PackedInt32Array([k+1,k+4,k+2,k+2,k+4,k+5]))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = verts
 arrays[Mesh.ARRAY_INDEX] = indices
 var surface := ArrayMesh.new()
 surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var bottom := MeshInstance3D.new()
 bottom.name = "GarboardAndKeelBottom"
 bottom.mesh = surface
 bottom.material_override = shell_mat
 add_child(bottom)

func add_curved_frame(member_name: String, points: PackedVector3Array, radius: float, mat: Material) -> void:
 # Uses Godot's built-in procedural mesh API: no unlicensed third-party geometry.
 # Multiple short cylinders share one parent frame, so the visual rib follows stations.
 var frame := Node3D.new()
 frame.name = member_name
 add_child(frame)
 for j in range(points.size()-1):
  var p0: Vector3 = points[j]
  var p1: Vector3 = points[j+1]
  var axis: Vector3 = p1-p0
  var part := MeshInstance3D.new()
  var beam := CylinderMesh.new()
  beam.top_radius = radius
  beam.bottom_radius = radius
  beam.height = axis.length()+0.02
  beam.radial_segments = 8
  part.mesh = beam
  part.material_override = mat
  part.position = (p0+p1)*0.5
  part.quaternion = Quaternion(Vector3.UP,axis.normalized())
  frame.add_child(part)

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

func _prefer_closed_original_hull() -> void:
 var original := boat.get_node_or_null("HullVisual")
 if original == null:
  return
 var closed_hull := original.find_child("V6_closed_hull",true,false) as MeshInstance3D
 var old_hull := original.find_child("legacy_000_Fairing-study wooden hull",true,false) as MeshInstance3D
 if closed_hull != null and old_hull != null:
  old_hull.visible = false
  print("APEX hull silhouette: original V6 closed hull retained; outdated overlapping legacy fairing hull hidden")
 else:
  print("APEX hull silhouette: no hull removed; closed=",closed_hull != null," legacy=",old_hull != null)

func _audit_original_projection_meshes() -> void:
 # Non-destructive: report protruding components before deciding what to hide.
 var original := boat.get_node_or_null("HullVisual")
 if original == null:
  return
 var examined := 0
 for child in original.find_children("*","MeshInstance3D",true,false):
  var part := child as MeshInstance3D
  if part == null or part.mesh == null:
   continue
  var local_center: Vector3 = original.to_local(part.to_global(part.mesh.get_aabb().get_center()))
  # Report high visible projections as well as overboard pieces; do not hide true rigging.
  var local_aabb: AABB = part.mesh.get_aabb()
  var local_size: Vector3 = local_aabb.size
  if local_center.y > 2.5 and local_center.y < 8.0 and (local_size.y > 0.8 or local_size.z > 1.0):
   print("APEX DECK PROJECTION ",part.name," center=",local_center," size=",local_size)
  if absf(local_center.x) > 3.8 or local_center.z < -15.0 or local_center.z > 15.0:
   if examined < 24:
    print("APEX PROJECTION AUDIT ",part.name," at ",local_center)
   examined += 1
 print("APEX PROJECTION AUDIT outlying mesh count: ",examined)
