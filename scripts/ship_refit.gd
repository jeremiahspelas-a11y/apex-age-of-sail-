extends RefCounted
## Refit the existing V6 station lines and V9 fittings; never modify the source GLB.
## This is an assembled render shell, not a new hydrostatics simulation or a surveyed plan.
const STATIONS := [-13.0,-12.0,-10.0,-8.0,-5.0,0.0,5.0,8.0,10.0,12.0,13.2]
const BEAMS := [0.2,1.3,2.45,3.1,3.35,3.45,3.3,3.0,2.5,1.55,0.28]
const BOTTOMS := [-1.0,-1.55,-1.9,-2.0,-2.1,-2.15,-2.175,-2.2,-2.2,-2.0,-1.25]
const MAST_STEP_Y := -1.26
const MAIN_TOP := 1.13
const MAIN_BOTTOM := 0.91
const QUARTER_TOP := 2.36
const FORE_TOP := 2.06
const HATCHES := [Rect2(-0.575,-4.6,1.15,1.2),Rect2(-0.575,1.4,1.15,1.2)]
const FORE_STAIR := Rect2(-0.70,-9.70,1.40,1.25)
const WHIPSTAFF_SLOT := Rect2(-0.30,11.25,0.60,0.40)
const QUARTER_STAIR := Rect2(-0.80,6.7,1.6,3.0)

static func beam_at(z: float) -> float:
 return sample(BEAMS,z)

static func sample(values: Array, z: float) -> float:
 for i in range(STATIONS.size()-1):
  if z <= STATIONS[i+1]:
   return lerpf(values[i],values[i+1],clampf(inverse_lerp(STATIONS[i],STATIONS[i+1],z),0.0,1.0))
 return values[-1]

static func deck_width(z: float, limit: float = 2.95) -> float:
 return maxf(0.08,minf(limit,beam_at(z)-0.12))

static func rail_width(z: float) -> float:
 var width := deck_width(z)
 width = lerpf(width,minf(width,2.05),smoothstep(7.3,9.0,-z))
 return lerpf(width,minf(width,2.65),smoothstep(6.4,8.95,z))

static func rail_deck(z: float) -> float:
 var fore := smoothstep(7.3,9.0,-z)
 var aft := smoothstep(6.4,8.95,z)
 return MAIN_TOP + fore*(FORE_TOP-MAIN_TOP) + aft*(QUARTER_TOP-MAIN_TOP)

static func find_mesh(root: Node, wanted: String) -> MeshInstance3D:
 for child in root.find_children("*","MeshInstance3D",true,false):
  if child.name == wanted:
   return child as MeshInstance3D
 return null

static func apply(boat: Node3D) -> void:
 var root := boat.get_node_or_null("HullVisual")
 if root == null or root.has_meta("ship_refit_applied"):
  return
 var hull := find_mesh(root,"V6_closed_hull")
 var main := find_mesh(root,"solid_main_deck")
 var fore := find_mesh(root,"solid_forecastle")
 var quarter := find_mesh(root,"solid_quarterdeck")
 if hull == null or main == null or fore == null or quarter == null:
  push_error("SHIP REFIT: required original hull/decks missing; original geometry retained")
  return
 root.set_meta("ship_refit_applied",true)
 # Retain every imported node. Only mutually superseded surfaces/fittings are hidden.
 for part in root.find_children("*","MeshInstance3D",true,false):
  var n := str(part.name)
  if n in ["legacy_000_Fairing-study wooden hull","legacy_001_Main deck","legacy_002_Raised quarterdeck","legacy_003_Forecastle"] or "Bulwark rail" in n or "Bulwark stanchion" in n or n.begins_with("V9_rail_post_") or n.begins_with("V9_lower_deck_collision_section"):
   part.visible = false
 # Preserve the V6 lower station shape and beam/draft; fair the topsides to the deck rim.
 # The roof is supplied by the actual decks, with intentional hatch openings.
 hull.mesh = hull_mesh(false)
 hull.set_meta("source_station_count",STATIONS.size())
 main.mesh = deck_mesh(-13.0,13.2,MAIN_BOTTOM,MAIN_TOP,2.95,HATCHES)
 fore.mesh = deck_mesh(-12.9,-8.45,1.84,FORE_TOP,2.05,[FORE_STAIR])
 quarter.mesh = deck_mesh(6.7,11.8,2.14,QUARTER_TOP,2.65,quarter_openings(boat))
 _castle_walls(root,-12.9,-8.45,1.84,2.05,"Forecastle")
 _castle_walls(root,6.7,11.8,2.14,2.65,"Quarterdeck")
 _fit_rails(root)
 _fit_steps(root)
 _fit_mast_steps(root)
 _fit_original_frames_and_lower_deck(root)
 _fit_standing_rig(root)
 _hatch_coamings(root)
 print("SHIP REFIT: V6 station hull, tapered decks, closed castle sides, continuous rails and stairs fitted")

static func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,outward: Vector3) -> void:
 # Godot front faces use clockwise winding.
 var points := [a,b,c]
 if (b-a).cross(c-a).dot(outward) > 0.0:
  points = [a,c,b]
 for p: Vector3 in points:
  st.set_uv(Vector2(p.x,p.z))
  st.add_vertex(p)

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,outward: Vector3) -> void:
 _triangle(st,a,b,c,outward)
 _triangle(st,a,c,d,outward)

static func _finish(st: SurfaceTool) -> ArrayMesh:
 st.generate_normals()
 st.index()
 return st.commit()

static func hull_profile(z: float) -> PackedVector3Array:
 var points := PackedVector3Array()
 var beam := beam_at(z)
 var bottom := sample(BOTTOMS,z)
 # Same lower ellipses as the original V6 rings, followed by a fair upper side.
 points.append(Vector3(deck_width(z),MAIN_BOTTOM,z))
 for i in range(13):
  var angle: float = float(i)*PI/12.0
  points.append(Vector3(beam*cos(angle),-0.5 + (-0.5-bottom)*-sin(angle),z))
 points.append(Vector3(-deck_width(z),MAIN_BOTTOM,z))
 return points

static func hull_mesh(include_deck: bool) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 for i in range(STATIONS.size()-1):
  var p := hull_profile(STATIONS[i])
  var q := hull_profile(STATIONS[i+1])
  for j in range(p.size()-1):
   var center := (p[j]+p[j+1]+q[j]+q[j+1])*0.25
   _quad(st,p[j],q[j],q[j+1],p[j+1],Vector3(center.x,center.y+0.5,0))
  if include_deck:
   _quad(st,p[0],p[-1],q[-1],q[0],Vector3.UP)
 for end in [0,STATIONS.size()-1]:
  var p := hull_profile(STATIONS[end])
  var center := Vector3(0,-0.5,STATIONS[end])
  var outward := Vector3(0,0,-1 if end == 0 else 1)
  st.set_smooth_group(-1)
  for j in range(p.size()-1):
   _triangle(st,center,p[j],p[j+1],outward)
  _triangle(st,center,p[-1],p[0],outward)
 return _finish(st)

static func deck_rows(start: float, end: float, holes: Array) -> Array[float]:
 var rows: Array[float] = [start,end]
 for z: float in STATIONS:
  if z > start and z < end: rows.append(z)
 for hole: Rect2 in holes:
  for z in [hole.position.y,hole.end.y]:
   if z > start and z < end: rows.append(z)
 rows.sort()
 return rows

static func deck_cells(start: float,end: float,limit: float,holes: Array,level: float = MAIN_BOTTOM) -> Array[Dictionary]:
 var rows := deck_rows(start,end,holes)
 var cells: Array[Dictionary] = []
 for i in range(rows.size()-1):
  var a := rows[i]
  var b := rows[i+1]
  var cuts: Array[float] = []
  for hole: Rect2 in holes:
   if (a+b)*0.5 > hole.position.y and (a+b)*0.5 < hole.end.y:
    cuts.append(hole.position.x)
    cuts.append(hole.end.x)
  cuts.sort()
  var bounds: Array[float] = [-INF]
  bounds.append_array(cuts)
  bounds.append(INF)
  for j in range(bounds.size()-1):
   var mid := (bounds[j]+bounds[j+1])*0.5
   var skip := false
   if is_finite(mid):
    for hole: Rect2 in holes:
     if hole.has_point(Vector2(mid,(a+b)*0.5)): skip = true
   if skip: continue
   var wa := walking_width(a,level,limit)
   var wb := walking_width(b,level,limit)
   var l0 := maxf(-wa,bounds[j])
   var r0 := minf(wa,bounds[j+1])
   var l1 := maxf(-wb,bounds[j])
   var r1 := minf(wb,bounds[j+1])
   if r0 > l0 and r1 > l1:
    cells.append({"z0":a,"z1":b,"l0":l0,"r0":r0,"l1":l1,"r1":r1})
 return cells

static func deck_mesh(start: float,end: float,bottom: float,top: float,limit: float,holes: Array) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(-1)
 for c: Dictionary in deck_cells(start,end,limit,holes,bottom):
  var a := Vector3(c.l0,top,c.z0)
  var b := Vector3(c.r0,top,c.z0)
  var d := Vector3(c.l1,top,c.z1)
  var e := Vector3(c.r1,top,c.z1)
  var offset := Vector3(0,bottom-top,0)
  _quad(st,a,b,e,d,Vector3.UP)
  _quad(st,a+offset,d+offset,e+offset,b+offset,Vector3.DOWN)
  _quad(st,a,d,d+offset,a+offset,Vector3.LEFT)
  _quad(st,b,b+offset,e+offset,e,Vector3.RIGHT)
  _quad(st,a,a+offset,b+offset,b,Vector3.FORWARD)
  _quad(st,d,e,e+offset,d+offset,Vector3.BACK)
 return _finish(st)

static func _mesh(root: Node,name: String,mesh: Mesh) -> MeshInstance3D:
 var part := MeshInstance3D.new()
 part.name = name
 part.mesh = mesh
 root.add_child(part)
 return part

static func _box(root: Node,name: String,size: Vector3,position: Vector3) -> MeshInstance3D:
 var shape := BoxMesh.new()
 shape.size = size
 var part := _mesh(root,name,shape)
 part.position = position
 return part

static func _castle_walls(root: Node,start: float,end: float,top: float,limit: float,label: String) -> void:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(-1)
 var rows := deck_rows(start,end,[])
 for side in [-1.0,1.0]:
  for i in range(rows.size()-1):
   var a := Vector3(side*deck_width(rows[i],limit),MAIN_TOP,rows[i])
   var b := Vector3(side*deck_width(rows[i+1],limit),MAIN_TOP,rows[i+1])
   _quad(st,a,b,Vector3(b.x,top,b.z),Vector3(a.x,top,a.z),Vector3(side,0,0))
 # Close the fore and aft faces, leaving the central stair entrance on the quarterdeck.
 for z in [start,end]:
  var w := deck_width(z,limit)
  var spans := [Vector2(-w,w)]
  if label == "Quarterdeck" and z == start:
   spans = [Vector2(-w,-0.80),Vector2(0.80,w)]
  elif label == "Forecastle" and z == end:
   spans = [Vector2(-w,-0.70),Vector2(0.70,w)]
  for span: Vector2 in spans:
   _quad(st,Vector3(span.x,MAIN_TOP,z),Vector3(span.y,MAIN_TOP,z),Vector3(span.y,top,z),Vector3(span.x,top,z),Vector3(0,0,-1 if z == start else 1))
 _mesh(root,label+"WoodenSides",_finish(st))

static func _fit_rails(root: Node) -> void:
 for side in [-1.0,1.0]:
  var suffix := "-1" if side < 0 else "1"
  var bulwark := find_mesh(root,"solid_bulwark_"+suffix)
  var rail := find_mesh(root,"solid_rail_"+suffix)
  if bulwark != null:
   bulwark.mesh = _rail_strip(side,0.10,0.0,0.68,-10.5,10.5)
  if rail != null:
   rail.mesh = _rail_strip(side,0.10,1.03,1.20,-10.5,10.5)
  for part in root.find_children("rail_post_"+suffix+"_*","MeshInstance3D",true,false):
   var mesh := part as MeshInstance3D
   var center := mesh.mesh.get_aabb().get_center()
   mesh.position.x = side*(rail_width(center.z)-0.10)-center.x
   mesh.position.y = rail_deck(center.z)-MAIN_TOP
  # Finish the formerly open bow/stern upperworks using the same sheer curve.
  _mesh(root,"BowBulwark_"+suffix,_rail_strip(side,0.10,0.0,0.85,-12.85,-10.5))
  _mesh(root,"BowCaprail_"+suffix,_rail_strip(side,0.12,0.85,1.00,-12.85,-10.5))
  _mesh(root,"SternBulwark_"+suffix,_rail_strip(side,0.10,0.0,0.85,10.5,11.8))
  _mesh(root,"SternCaprail_"+suffix,_rail_strip(side,0.12,0.85,1.00,10.5,11.8))
 var w := deck_width(11.8,2.65)
 _box(root,"SternTransomBulwark",Vector3(w*2,0.85,0.18),Vector3(0,QUARTER_TOP+0.425,11.8))
 _box(root,"SternTransomCaprail",Vector3(w*2+0.12,0.15,0.24),Vector3(0,QUARTER_TOP+0.925,11.8))

static func _rail_strip(side: float,thickness: float,low: float,high: float,start: float,end: float) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(-1)
 var rows: Array[float] = [start,end]
 for k in range(int(ceil(start*2)),int(floor(end*2))+1):
  var z: float = float(k)*0.5
  if z > start and z < end: rows.append(z)
 rows.sort()
 for i in range(rows.size()-1):
  var z0 := rows[i]
  var z1 := rows[i+1]
  var x0 := side*maxf(0.02,rail_width(z0)-0.10)
  var x1 := side*maxf(0.02,rail_width(z1)-0.10)
  var y0 := rail_deck(z0)
  var y1 := rail_deck(z1)
  var a := Vector3(x0-thickness*0.5,y0+low,z0)
  var b := Vector3(x0+thickness*0.5,y0+low,z0)
  var c := Vector3(x1+thickness*0.5,y1+low,z1)
  var d := Vector3(x1-thickness*0.5,y1+low,z1)
  var up := Vector3(0,high-low,0)
  _quad(st,a,b,c,d,Vector3.DOWN)
  _quad(st,a+up,d+up,c+up,b+up,Vector3.UP)
  _quad(st,a,d,d+up,a+up,Vector3.LEFT)
  _quad(st,b,b+up,c+up,c,Vector3.RIGHT)
  if i == 0: _quad(st,a,a+up,b+up,b,Vector3.FORWARD)
  if i == rows.size()-2: _quad(st,d,c,c+up,d+up,Vector3.BACK)
 return _finish(st)

static func _fit_steps(root: Node) -> void:
 # Complete the measured quarterdeck stair run to the actual 2.36 m deck surface.
 for k in range(7,9):
  var top := minf(QUARTER_TOP,1.20+float(k)*0.15)
  _box(root,"QuarterdeckStairRefit_%d"%k,Vector3(1.40,0.16,0.38),Vector3(0,top-0.08,6.4+float(k)*0.38))
 # A short companion stair connects the main and forecastle decks.
 for k in range(5):
  var top := lerpf(MAIN_TOP,FORE_TOP,float(k+1)/5.0)
  _box(root,"ForecastleStair_%d"%k,Vector3(1.30,0.16,0.34),Vector3(0,top-0.08,-7.95-float(k)*0.34))
 _box(root,"ForecastleStairLanding",Vector3(1.40,0.16,0.56),Vector3(0,FORE_TOP-0.08,-9.42))

static func _hatch_coamings(root: Node) -> void:
 for i in range(HATCHES.size()):
  var h: Rect2 = HATCHES[i]
  var y := (MAIN_TOP+1.34)*0.5
  var height := 1.34-MAIN_TOP
  for x in [h.position.x-0.05,h.end.x+0.05]:
   _box(root,"HatchCoamingSide_%d"%i,Vector3(0.10,height,h.size.y+0.20),Vector3(x,y,h.get_center().y))
  for z in [h.position.y-0.05,h.end.y+0.05]:
   _box(root,"HatchCoamingEnd_%d"%i,Vector3(h.size.x,height,0.10),Vector3(0,y,z))

static func _tube(st: SurfaceTool,a: Vector3,b: Vector3,radius: float) -> void:
 var axis := (b-a).normalized()
 var reference := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
 var u := axis.cross(reference).normalized()*radius
 var v := axis.cross(u).normalized()*radius
 for k in range(6):
  var t0 := TAU*float(k)/6.0
  var t1 := TAU*float(k+1)/6.0
  var p := u*cos(t0)+v*sin(t0)
  var q := u*cos(t1)+v*sin(t1)
  _quad(st,a+p,b+p,b+q,a+q,(p+q).normalized())

static func _shroud_mesh(mast_z: float,collar_y: float,side: float) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 var top := Vector3(0,collar_y,mast_z)
 var feet: Array[Vector3] = []
 for offset in [-1.4,0.0,1.4]:
  var z: float = mast_z+offset
  var foot := Vector3(side*(rail_width(z)-0.06),rail_deck(z)-0.08,z)
  feet.append(foot)
  _tube(st,foot,top,0.035)
 var rise := collar_y-maxf(feet[0].y,feet[2].y)
 var steps := int(rise*0.68/0.45)
 for i in range(1,steps+1):
  var t := float(i)*0.45/rise
  _tube(st,feet[0].lerp(top,t),feet[2].lerp(top,t),0.012)
 return _finish(st)

static func _fit_standing_rig(root: Node) -> void:
 var source: Array[MeshInstance3D] = []
 for i in range(6):
  var name := "shroud_tube" if i == 0 else "shroud_tube_"+str(i)
  var part := find_mesh(root,name)
  if part == null: return
  source.append(part)
 # Both original shroud generations were offset from their own mast centers.
 # Reuse the six newer meshes at the measured mast collars and chainplate feet.
 for part in root.find_children("*","MeshInstance3D",true,false):
  if str(part.name).begins_with("legacy_") and "Shroud" in str(part.name): part.visible = false
 var z_positions := [-6.5,3.1,10.8]
 var collars := [16.0,20.0,12.5]
 for side_index in range(2):
  var side := -1.0 if side_index == 0 else 1.0
  for mast in range(3):
   source[side_index*3+mast].mesh = _shroud_mesh(z_positions[mast],collars[mast],side)
   source[side_index*3+mast].set_meta("rig_collar",Vector3(0,collars[mast],z_positions[mast]))
   for offset in [-1.4,0.0,1.4]:
    var z: float = z_positions[mast]+offset
    _box(root,"IronChainplate_%s_%d_%s"%[str(side),mast,str(offset)],Vector3(0.08,0.55,0.10),Vector3(side*(rail_width(z)-0.06),rail_deck(z)-0.3,z))
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 _tube(st,Vector3(0,17.5,-6.5),Vector3(0,4.45,-17.5),0.04)
 _tube(st,Vector3(0,20.8,3.1),Vector3(0,1.45,-6.5),0.04)
 _tube(st,Vector3(0,12.8,10.8),Vector3(0,2.0,3.1),0.03)
 _mesh(root,"StandingRiggingStays",_finish(st))

static func walking_width(z: float,y: float,limit: float) -> float:
 if y >= 0.0: return deck_width(z,limit)
 var depth := -0.5-sample(BOTTOMS,z)
 var fraction := clampf((-0.5-y)/depth,0.0,0.99)
 return maxf(0.08,minf(limit,beam_at(z)*sqrt(1.0-fraction*fraction)-0.12))

static func _fit_mast_steps(root: Node) -> void:
 for i in range(1,4):
  var mast: MeshInstance3D = null
  for part in root.find_children("*","MeshInstance3D",true,false):
   if str(part.name).ends_with("Mast "+str(i)): mast = part
  if mast == null: continue
  var bounds := mast.mesh.get_aabb()
  var arrays := mast.mesh.surface_get_arrays(0)
  var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  for j in vertices.size():
   if absf(vertices[j].y-bounds.position.y) < 0.001: vertices[j].y = MAST_STEP_Y
  arrays[Mesh.ARRAY_VERTEX] = vertices
  var mesh := ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mast.mesh = mesh
  var z := bounds.get_center().z
  var deck := QUARTER_TOP if i == 3 else MAIN_TOP
  for side in [-1.0,1.0]:
   _box(root,"MastPartnersSide_%d_%s"%[i,str(side)],Vector3(0.12,0.14,0.70),Vector3(side*0.34,deck+0.04,z))
   _box(root,"MastPartnersEnd_%d_%s"%[i,str(side)],Vector3(0.56,0.14,0.12),Vector3(0,deck+0.04,z+side*0.29))

static func _fit_original_frames_and_lower_deck(root: Node) -> void:
 for part in root.find_children("*","MeshInstance3D",true,false):
  var n := str(part.name)
  var bounds: AABB = part.mesh.get_aabb()
  if n.begins_with("v7_lower_deck_plank_"):
   part.mesh = deck_mesh(bounds.position.z,bounds.end.z,bounds.position.y,bounds.end.y,2.325,[])
  elif n.begins_with("frame_"):
   var z := bounds.get_center().z
   var side := signf(bounds.get_center().x)
   var profile := hull_profile(z)
   var st := SurfaceTool.new()
   st.begin(Mesh.PRIMITIVE_TRIANGLES)
   st.set_smooth_group(0)
   var points: Array[Vector3] = []
   if side > 0:
    for i in range(8): points.append(profile[i])
   else:
    for i in range(7,profile.size()): points.append(profile[i])
   for i in range(points.size()):
    points[i].x -= side*0.12
    points[i].y = minf(points[i].y+0.05,MAIN_BOTTOM-0.10)
   for i in range(points.size()-1): _tube(st,points[i],points[i+1],0.07)
   part.mesh = _finish(st)

static func quarter_openings(boat: Node) -> Array:
 var openings: Array = [QUARTER_STAIR]
 var mechanisms := boat.get_node_or_null("Mechanisms")
 if mechanisms != null and mechanisms.use_whipstaff:
  openings.append(WHIPSTAFF_SLOT)
 else:
  openings.append(Rect2(-0.37,11.59,0.08,0.08))
  openings.append(Rect2(0.29,11.59,0.08,0.08))
 return openings
