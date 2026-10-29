extends RefCounted
## Displaced-volume quadrature of the refitted hull, independent of scripted motion.
## Body-fixed columns clip against a sampled heightfield; no CFD or slamming model.
const DENSITY := 1025.0
const GRAVITY := 9.8
var columns: Array[Dictionary] = []
var bounds := AABB()
var full_volume := 0.0
var water_rows := 7
var damping_rates := Vector3(0.90,1.40,0.08) # empirical 1/s, transverse/heave/longitudinal

## section_at(z) returns a closed, convex cross-section as body-local Vector3 points.
## The solver has no scene, ocean singleton, input or APEX asset dependency.
func build_from_sections(section_at: Callable,hull_bounds: AABB,nx: int = 20,nz: int = 40) -> void:
 assert(section_at.is_valid() and nx > 0 and nz > 0 and hull_bounds.size.x > 0.0 and hull_bounds.size.z > 0.0)
 bounds = hull_bounds
 columns.clear()
 full_volume = 0.0
 var dx := bounds.size.x/float(nx)
 var dz := bounds.size.z/float(nz)
 for iz in nz:
  var z := bounds.position.z+(float(iz)+0.5)*dz
  var profile: PackedVector3Array = section_at.call(z)
  for ix in nx:
   var x := bounds.position.x+(float(ix)+0.5)*dx
   var intersections: Array[float] = []
   for k in profile.size():
    var a := profile[k]
    var b := profile[(k+1)%profile.size()]
    if absf(a.x-b.x) < 0.000001: continue
    if x >= minf(a.x,b.x) and x < maxf(a.x,b.x):
     intersections.append(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
   if intersections.size() < 2: continue
   intersections.sort()
   _add_column(x,z,intersections[0],intersections[-1],dx*dz)

func build_box(size: Vector3,nx: int = 20,nz: int = 40) -> void:
 assert(nx > 0 and nz > 0 and size.x > 0.0 and size.y > 0.0 and size.z > 0.0)
 bounds = AABB(-size*0.5,size)
 columns.clear()
 full_volume = 0.0
 for iz in nz:
  for ix in nx:
   _add_column(bounds.position.x+(float(ix)+0.5)*size.x/nx,bounds.position.z+(float(iz)+0.5)*size.z/nz,bounds.position.y,bounds.end.y,size.x*size.z/float(nx*nz))

func _add_column(x: float,z: float,bottom: float,top: float,area: float) -> void:
 if top <= bottom: return
 var volume := (top-bottom)*area
 columns.append({"bottom":Vector3(x,bottom,z),"top":Vector3(x,top,z),"volume":volume})
 full_volume += volume

func _water_samples(transform: Transform3D,height_at: Callable) -> PackedFloat64Array:
 var heights := PackedFloat64Array()
 for row in water_rows:
  var z := lerpf(bounds.position.z,bounds.end.z,float(row)/float(water_rows-1))
  for side in 3:
   var p := transform*Vector3(lerpf(bounds.position.x,bounds.end.x,float(side)*0.5),0,z)
   heights.append(float(height_at.call(p.x,p.z)))
 return heights

func _surface(p: Vector3,heights: PackedFloat64Array) -> float:
 var fx := clampf((p.x-bounds.position.x)/bounds.size.x*2.0,0.0,2.0)
 var fz := clampf((p.z-bounds.position.z)/bounds.size.z*float(water_rows-1),0.0,float(water_rows-1))
 var ix := mini(int(fx),1)
 var iz := mini(int(fz),water_rows-2)
 var a := lerpf(heights[iz*3+ix],heights[iz*3+ix+1],fx-ix)
 var b := lerpf(heights[(iz+1)*3+ix],heights[(iz+1)*3+ix+1],fx-ix)
 return lerpf(a,b,fz-iz)

func evaluate(transform: Transform3D,height_at: Callable,local_com: Vector3 = Vector3.ZERO,linear: Vector3 = Vector3.ZERO,angular: Vector3 = Vector3.ZERO,flow_at: Callable = Callable()) -> Dictionary:
 var heights := _water_samples(transform,height_at)
 var flows := PackedVector3Array()
 if flow_at.is_valid():
  for row in water_rows:
   for side in 3:
    var p := transform*Vector3(lerpf(bounds.position.x,bounds.end.x,float(side)*0.5),0,lerpf(bounds.position.z,bounds.end.z,float(row)/float(water_rows-1)))
    flows.append(flow_at.call(p.x,p.z))
 var com := transform*local_com
 var buoyancy := Vector3.ZERO
 var moment := Vector3.ZERO
 var drag := Vector3.ZERO
 var drag_moment := Vector3.ZERO
 var volume := 0.0
 var weighted_center := Vector3.ZERO
 var inverse := transform.basis.transposed()
 for column: Dictionary in columns:
  var bottom: Vector3 = transform*column.bottom
  var top: Vector3 = transform*column.top
  var surface := _surface(column.bottom,heights)
  # Invert the interval too, so overturning does not create negative volume.
  var fraction := 0.0
  var center := Vector3.ZERO
  if top.y >= bottom.y:
   fraction = clampf((surface-bottom.y)/maxf(top.y-bottom.y,0.000001),0.0,1.0)
   center = bottom.lerp(top,fraction*0.5)
  else:
   fraction = clampf((surface-top.y)/maxf(bottom.y-top.y,0.000001),0.0,1.0)
   center = top.lerp(bottom,fraction*0.5)
  var displaced: float = column.volume*fraction
  if displaced <= 0.0: continue
  var force := Vector3.UP*(DENSITY*GRAVITY*displaced)
  var arm := center-com
  var point_velocity := linear+angular.cross(arm)
  if not flows.is_empty():
   var fx := clampf((column.bottom.x-bounds.position.x)/bounds.size.x*2.0,0.0,2.0)
   var fz := clampf((column.bottom.z-bounds.position.z)/bounds.size.z*float(water_rows-1),0.0,float(water_rows-1))
   var ix := mini(int(fx),1)
   var iz := mini(int(fz),water_rows-2)
   var a := flows[iz*3+ix].lerp(flows[iz*3+ix+1],fx-ix)
   var b := flows[(iz+1)*3+ix].lerp(flows[(iz+1)*3+ix+1],fx-ix)
   point_velocity -= a.lerp(b,fz-iz)
  var local_velocity := inverse*point_velocity
  var resistance := transform.basis*(-local_velocity*damping_rates)*(DENSITY*displaced)
  buoyancy += force
  moment += arm.cross(force)
  drag += resistance
  drag_moment += arm.cross(resistance)
  weighted_center += center*displaced
  volume += displaced
 return {"volume":volume,"buoyancy":Vector3.UP*(DENSITY*GRAVITY*volume),"buoyancy_torque":moment,"drag":drag,"drag_torque":drag_moment,"center":weighted_center/maxf(volume,0.000001)}

func equilibrium_height(mass_kg: float,local_com: Vector3 = Vector3.ZERO) -> float:
 var low := -bounds.end.y-1.0
 var high := -bounds.position.y+1.0
 var flat := func(_x: float,_z: float) -> float: return 0.0
 for i in 32:
  var middle := (low+high)*0.5
  var result := evaluate(Transform3D(Basis.IDENTITY,Vector3(0,middle,0)),flat,local_com)
  if result.volume*DENSITY > mass_kg: low = middle
  else: high = middle
 return (low+high)*0.5
