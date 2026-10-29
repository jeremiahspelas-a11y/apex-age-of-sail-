extends RefCounted
## Low-resolution XPBD membrane. SI units; world-space particles, head fixed to yard.
## Flat cut pattern, pressure-driven billow and frictionless spar contact. No self-contact/tears.
const Contact = preload("res://scripts/sail_contact.gd")
enum Hold {BELAYED,HAND,FREE,CUT}
const COLUMNS := 6
const ROWS := 4
const SUBSTEP := 1.0/240.0
var rest := PackedVector3Array()
var points := PackedVector3Array()
var velocities := PackedVector3Array()
var masses := PackedFloat64Array()
var constraints: Array[Dictionary] = []
var triangles := PackedInt32Array()
var lines: Array[Dictionary] = []
var pose := Transform3D.IDENTITY
var fixture_transform := Transform3D.IDENTITY
var canvas_mass := 0.0
var area := 0.0
var hand_force_limit := 180.0
var hand_speed := 0.35
var areal_mass := 0.6 # provisional kg/m2, not calibrated historical canvas
var gravity := Vector3(0,-9.81,0)
var damping := 0.7
var report: Dictionary = {}
# Optional unscaled capsule envelopes in fixture or sail mesh coordinates.
var capsules: Array[Dictionary] = []
var contact_thickness := 0.012
var head_standoff := 0.0

func set_capsules(envelopes: Array[Dictionary]) -> void:
 capsules = envelopes.duplicate(true)

func _world_capsules() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for capsule: Dictionary in capsules:
  var frame: Transform3D = pose if capsule.get("yard",false) else fixture_transform
  result.append({"a":frame*capsule.a,"b":frame*capsule.b,"radius":capsule.radius,"yard":capsule.get("yard",false)})
 return result

func configure(bounds: AABB,head_z: float,initial_pose: Transform3D,leads: Array[Vector3],pins: Array[Vector3],fixture_pose: Transform3D = Transform3D.IDENTITY) -> void:
 fixture_transform = fixture_pose
 rest.clear()
 constraints.clear()
 triangles.clear()
 area = 0.0
 for row in ROWS+1:
  var v := float(row)/ROWS
  for col in COLUMNS+1:
   var u := float(col)/COLUMNS
   rest.append(Vector3(bounds.get_center().x+(u-0.5)*bounds.size.x*lerpf(1.0,0.88,v),bounds.end.y-v*bounds.size.y+sin(u*PI)*pow(v,4.0)*bounds.size.y*0.075,head_z-head_standoff))
 masses.resize(rest.size())
 masses.fill(0.0)
 for row in ROWS:
  for col in COLUMNS:
   var a := row*(COLUMNS+1)+col
   for tri: Array in [[a,a+COLUMNS+2,a+1],[a,a+COLUMNS+1,a+COLUMNS+2]]:
    var triangle_area: float = (rest[tri[1]]-rest[tri[0]]).cross(rest[tri[2]]-rest[tri[0]]).length()*0.5
    area += triangle_area
    for index: int in tri:
     triangles.append(index)
     # Top strip mass is lumped onto its nearest free row, not discarded.
     var mass_index := index+COLUMNS+1 if index<=COLUMNS else index
     masses[mass_index] += triangle_area*areal_mass/3.0
 canvas_mass = 0.0
 for mass_value in masses: canvas_mass += mass_value
 for row in ROWS+1:
  for col in COLUMNS+1:
   var i := row*(COLUMNS+1)+col
   if col<COLUMNS: _constraint(i,i+1,0.00001)
   if row<ROWS: _constraint(i,i+COLUMNS+1,0.00001)
   if col<COLUMNS and row<ROWS:
    _constraint(i,i+COLUMNS+2,0.0002)
    _constraint(i+1,i+COLUMNS+1,0.0002)
   if col<COLUMNS-1: _constraint(i,i+2,0.02)
   if row<ROWS-1: _constraint(i,i+2*(COLUMNS+1),0.02)
 reset(initial_pose)
 lines.clear()
 for i in 2:
  var clew := ROWS*(COLUMNS+1)+(0 if i==0 else COLUMNS)
  var tail := leads[i].distance_to(pins[i])
  var length := points[clew].distance_to(fixture_pose*leads[i])+tail
  lines.append({"lead":leads[i],"belay":pins[i],"tail":tail,"length":length,"velocity":0.0,"tension":0.0,"mode":Hold.BELAYED,"pull":0.0,"hand_force":0.0,"minimum":tail+0.3,"maximum":length+5.0,"node":clew,"lambda":0.0})

func _constraint(a: int,b: int,compliance: float) -> void:
 constraints.append({"a":a,"b":b,"length":rest[a].distance_to(rest[b]),"compliance":compliance,"lambda":0.0})

func reset(initial_pose: Transform3D) -> void:
 pose = initial_pose
 points.resize(rest.size())
 velocities.resize(rest.size())
 velocities.fill(Vector3.ZERO)
 for i in rest.size(): points[i] = pose*rest[i]
 report.clear()

func set_hand(index: int,pull: float) -> void:
 if index not in [0,1] or lines[index].mode==Hold.CUT: return
 lines[index].mode = Hold.HAND
 lines[index].pull = clampf(pull,-1.0,1.0)
func stop_hands() -> void:
 for line: Dictionary in lines: line.pull = 0.0
func belay(index: int) -> void:
 if lines[index].mode==Hold.CUT: return
 lines[index].mode = Hold.BELAYED
 lines[index].velocity = 0.0
 lines[index].pull = 0.0
func release(index: int) -> void:
 if lines[index].mode==Hold.CUT: return
 lines[index].mode = Hold.FREE
 lines[index].pull = 0.0
func cut(index: int) -> void:
 lines[index].mode = Hold.CUT
 lines[index].tension = 0.0
 lines[index].pull = 0.0
 lines[index].hand_force = 0.0

func pressure(wind: Vector3,reef: float = 1.0,step_h: float = 0.0) -> PackedVector3Array:
 var forces := PackedVector3Array()
 forces.resize(points.size())
 forces.fill(Vector3.ZERO)
 for t in range(0,triangles.size(),3):
  var a := triangles[t]
  var b := triangles[t+1]
  var c := triangles[t+2]
  var cross_product := (points[b]-points[a]).cross(points[c]-points[a])
  var size := cross_product.length()
  if size<0.0000001: continue
  var normal := cross_product/size
  var speed := (wind-(velocities[a]+velocities[b]+velocities[c])/3.0).dot(normal)
  var coefficient := 0.5*1.225*0.8*clampf(reef,0,1)
  # Analytic quadratic-drag relaxation of a local patch over this substep.
  # Explicit V^2 drag can overshoot air velocity after a contact impulse and
  # add energy indefinitely. This averages the patch's decaying relative speed;
  # h=0 still reports instantaneous pressure for diagnostics.
  var relaxation := 1.0+step_h*coefficient*absf(speed)/areal_mass
  var load := normal*(coefficient*speed*absf(speed)*size*0.5/(3.0*relaxation))
  forces[a] += load
  forces[b] += load
  forces[c] += load
 return forces

func momentum(origin: Vector3 = Vector3.ZERO) -> Dictionary:
 var linear := Vector3.ZERO
 var angular := Vector3.ZERO
 for i in points.size():
  var p := velocities[i]*masses[i]
  linear += p
  angular += (points[i]-origin).cross(p)
 return {"linear":linear,"angular":angular}

func step(delta: float,next_pose: Transform3D,wind: Vector3,reef: float,com: Vector3,hinge: Vector3,fixture_pose: Transform3D = Transform3D.IDENTITY) -> Dictionary:
 if points.is_empty() or delta<=0: return {}
 var count := maxi(1,int(ceil(delta/SUBSTEP)))
 var h := delta/count
 var force := Vector3.ZERO
 var torque := Vector3.ZERO
 var wind_force := Vector3.ZERO
 var top_torque := Vector3.ZERO
 var contact_count := 0
 var old_pose := pose
 var old_fixture := fixture_transform
 for sub in count:
  var previous_support := pose
  pose = old_pose.interpolate_with(next_pose,float(sub+1)/count)
  fixture_transform = old_fixture.interpolate_with(fixture_pose,float(sub+1)/count)
  var carried_motion := pose*previous_support.affine_inverse()
  var before := momentum(com)
  var previous := points.duplicate()
  var loads := pressure(wind,reef,h)
  var external := Vector3.ZERO
  var external_torque := Vector3.ZERO
  var top_load := Vector3.ZERO
  for i in points.size():
   wind_force += loads[i]/count
   loads[i] += gravity*masses[i]
   external += loads[i]
   external_torque += (points[i]-com).cross(loads[i])
   if masses[i]==0:
    points[i] = pose*rest[i]
    top_load += (points[i]-hinge).cross(loads[i])
   else:
    var carried_velocity := (carried_motion*points[i]-points[i])/h
    velocities[i] = carried_velocity+(velocities[i]-carried_velocity)*exp(-damping*h)
    velocities[i] += loads[i]*(h/masses[i])
    points[i] += velocities[i]*h
  for constraint: Dictionary in constraints: constraint["lambda"] = 0.0
  var old_lengths := PackedFloat64Array()
  for line: Dictionary in lines:
   old_lengths.append(line.length)
   line["lambda"] = 0.0
   line.hand_force = 0.0
   if line.mode in [Hold.HAND,Hold.FREE]:
    if line.mode==Hold.HAND:
     line.hand_force = clampf((line.pull*hand_speed-line.velocity)*2.0/0.08-line.tension,-hand_force_limit,hand_force_limit)
    line.velocity += (line.hand_force-2.5*line.velocity)*h/2.0
    line.length += line.velocity*h
  var world_capsules := _world_capsules()
  for iteration in 6:
   for constraint: Dictionary in constraints:
    var a: int = constraint.a
    var b: int = constraint.b
    var displacement := points[b]-points[a]
    var distance := displacement.length()
    if distance<0.000001: continue
    var wa := 0.0 if masses[a]==0 else 1.0/masses[a]
    var wb := 0.0 if masses[b]==0 else 1.0/masses[b]
    if wa+wb==0: continue
    var alpha: float = constraint.compliance/(h*h)
    var dl: float = (-(distance-constraint.length)-alpha*constraint["lambda"])/(wa+wb+alpha)
    constraint["lambda"] += dl
    var correction := displacement/distance*dl
    points[a] -= correction*wa
    points[b] += correction*wb
   for line: Dictionary in lines:
    if line.mode==Hold.CUT: continue
    var lead: Vector3 = fixture_transform*line.lead
    var i: int = line.node
    var displacement := points[i]-lead
    var distance := displacement.length()
    if distance<0.000001: continue
    var w := 1.0/masses[i]
    var wq := 0.5 if line.mode in [Hold.HAND,Hold.FREE] else 0.0
    var alpha := 0.00005/(h*h)
    var c: float = distance+line.tail-line.length
    var dl: float = (-c-alpha*line["lambda"])/(w+wq+alpha)
    var new_lambda := minf(0.0,line["lambda"]+dl)
    dl = new_lambda-line["lambda"]
    line["lambda"] = new_lambda
    points[i] += displacement/distance*dl*w
    line.length -= dl*wq
   # Contact is solved after material/rope constraints, including triangle interiors.
   if not world_capsules.is_empty():
    var contact := Contact.solve(points,masses,triangles,previous,world_capsules,contact_thickness,h,hinge)
    contact_count += contact.count
    top_load += contact.yard_torque
  for constraint: Dictionary in constraints:
   var a: int = constraint.a
   var b: int = constraint.b
   if masses[a]!=0 and masses[b]!=0: continue
   var direction := (points[b]-points[a]).normalized()
   var pin := a if masses[a]==0 else b
   var pin_force := direction*float(constraint["lambda"])/(h*h)*(-1.0 if pin==a else 1.0)
   top_load += (points[pin]-hinge).cross(pin_force)
  for i in points.size(): velocities[i] = (points[i]-previous[i])/h
  for i in lines.size():
   var line: Dictionary = lines[i]
   line.tension = -line["lambda"]/(h*h) if line["lambda"]<0.0 and line.mode!=Hold.CUT else 0.0
   if line.mode in [Hold.HAND,Hold.FREE]:
    line.length = maxf(line.minimum,line.length)
    line.velocity = (line.length-old_lengths[i])/h
    if line.length>line.maximum: cut(i)
  var after := momentum(com)
  # Apply only support reaction to the hull: pressure/gravity minus cloth momentum gain.
  force += (external-(after.linear-before.linear)/h)/count
  torque += (external_torque-(after.angular-before.angular)/h)/count
  top_torque += top_load/count
 report = {"force":force,"torque":torque,"wind_force":wind_force,"top_torque":top_torque,"canvas_mass":canvas_mass,"contact_constraints":contact_count}
 return report

func build_mesh(mesh_pose: Transform3D) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 var inverse := mesh_pose.affine_inverse()
 for index in triangles:
  st.set_uv(Vector2(float(index%(COLUMNS+1))/COLUMNS,float(index/(COLUMNS+1))/ROWS))
  st.add_vertex(inverse*points[index])
 st.generate_normals()
 st.index()
 return st.commit()

func snapshot(body_pose: Transform3D) -> Dictionary:
 var local := PackedVector3Array()
 for point in points: local.append(body_pose.affine_inverse()*point)
 return {"points":local,"lines":lines.duplicate(true)}
func receive_snapshot(data: Dictionary,body_pose: Transform3D) -> void:
 if data.get("points",PackedVector3Array()).size()!=rest.size(): return
 points.clear()
 for point: Vector3 in data.points: points.append(body_pose*point)
 if data.get("lines",[]).size()==2: lines.assign(data.lines)
 pose = body_pose
