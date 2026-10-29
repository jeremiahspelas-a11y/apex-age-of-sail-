extends RefCounted
## Frictionless, two-sided triangle/capsule contact. No scene or rendering dependency.
## Analytic spar envelopes; not self-contact, continuous collision or exact mesh contact.
const EPS := 0.00000001

static func closest_triangle(p: Vector3,a: Vector3,b: Vector3,c: Vector3) -> Vector3:
 # Barycentric coordinates of the nearest point, including edges and vertices.
 var ab := b-a
 var ac := c-a
 if ab.cross(ac).length_squared()<EPS:
  var vertices := [a,b,c]
  var weights := [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)]
  var nearest_bary := Vector3(1,0,0)
  var nearest_distance := INF
  for i in 3:
   var j := (i+1)%3
   var pair := closest_segments(p,p,vertices[i],vertices[j])
   var q: Vector3 = vertices[i].lerp(vertices[j],pair.y)
   if q.distance_squared_to(p)<nearest_distance:
    nearest_distance = q.distance_squared_to(p)
    nearest_bary = weights[i].lerp(weights[j],pair.y)
  return nearest_bary
 var ap := p-a
 var d1 := ab.dot(ap)
 var d2 := ac.dot(ap)
 if d1<=0 and d2<=0: return Vector3(1,0,0)
 var bp := p-b
 var d3 := ab.dot(bp)
 var d4 := ac.dot(bp)
 if d3>=0 and d4<=d3: return Vector3(0,1,0)
 var vc := d1*d4-d3*d2
 if vc<=0 and d1>=0 and d3<=0:
  var v := d1/(d1-d3)
  return Vector3(1-v,v,0)
 var cp := p-c
 var d5 := ab.dot(cp)
 var d6 := ac.dot(cp)
 if d6>=0 and d5<=d6: return Vector3(0,0,1)
 var vb := d5*d2-d1*d6
 if vb<=0 and d2>=0 and d6<=0:
  var w := d2/(d2-d6)
  return Vector3(1-w,0,w)
 var va := d3*d6-d5*d4
 if va<=0 and d4-d3>=0 and d5-d6>=0:
  var w := (d4-d3)/((d4-d3)+(d5-d6))
  return Vector3(0,1-w,w)
 var denominator := va+vb+vc
 if absf(denominator)<EPS:
  # Degenerate panel: fall back to its nearest edge.
  var best := Vector3(1,0,0)
  var distance := p.distance_squared_to(a)
  for edge in [[a,b,Vector3(1,0,0),Vector3(0,1,0)],[b,c,Vector3(0,1,0),Vector3(0,0,1)],[c,a,Vector3(0,0,1),Vector3(1,0,0)]]:
   var length: float = (edge[1]-edge[0]).length_squared()
   var t := clampf((p-edge[0]).dot(edge[1]-edge[0])/length,0,1) if length>EPS else 0.0
   var q: Vector3 = edge[0].lerp(edge[1],t)
   if p.distance_squared_to(q)<distance:
    distance = p.distance_squared_to(q)
    best = edge[2].lerp(edge[3],t)
  return best
 var v := vb/denominator
 var w := vc/denominator
 return Vector3(1-v-w,v,w)

static func closest_segments(a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> Vector2:
 var u := b-a
 var v := d-c
 var w := a-c
 var aa := u.dot(u)
 var ee := v.dot(v)
 var f := v.dot(w)
 var s := 0.0
 var t := 0.0
 if aa<=EPS and ee<=EPS: return Vector2.ZERO
 if aa<=EPS: t = clampf(f/ee,0,1)
 else:
  var cc := u.dot(w)
  if ee<=EPS: s = clampf(-cc/aa,0,1)
  else:
   var bb := u.dot(v)
   var denominator := aa*ee-bb*bb
   s = clampf((bb*f-cc*ee)/denominator,0,1) if denominator>EPS else 0.0
   t = (bb*s+f)/ee
   if t<0:
    t = 0.0
    s = clampf(-cc/aa,0,1)
   elif t>1:
    t = 1.0
    s = clampf((bb-cc)/aa,0,1)
 return Vector2(s,t)

static func nearest(a: Vector3,b: Vector3,c: Vector3,start: Vector3,end: Vector3) -> Dictionary:
 var normal := (b-a).cross(c-a)
 var divisor := normal.dot(end-start)
 if absf(divisor)>EPS:
  var t := normal.dot(a-start)/divisor
  if t>=0 and t<=1:
   var point := start.lerp(end,t)
   var bary := closest_triangle(point,a,b,c)
   if (a*bary.x+b*bary.y+c*bary.z).distance_squared_to(point)<0.0000000001:
    return {"bary":bary,"axis":point,"point":point,"distance":0.0}
 var bary := closest_triangle(start,a,b,c)
 var point := a*bary.x+b*bary.y+c*bary.z
 var result := {"bary":bary,"axis":start,"point":point,"distance":point.distance_squared_to(start)}
 var weights := [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)]
 var vertices := [a,b,c]
 for endpoint in [end]:
  bary = closest_triangle(endpoint,a,b,c)
  point = a*bary.x+b*bary.y+c*bary.z
  var distance := point.distance_squared_to(endpoint)
  if distance<result.distance: result = {"bary":bary,"axis":endpoint,"point":point,"distance":distance}
 for i in 3:
  var j := (i+1)%3
  var pair := closest_segments(vertices[i],vertices[j],start,end)
  point = vertices[i].lerp(vertices[j],pair.x)
  var axis := start.lerp(end,pair.y)
  var distance := point.distance_squared_to(axis)
  if distance<result.distance:
   result = {"bary":weights[i].lerp(weights[j],pair.x),"axis":axis,"point":point,"distance":distance}
 result.distance = sqrt(result.distance)
 return result

static func solve(points: PackedVector3Array,masses: PackedFloat64Array,triangles: PackedInt32Array,previous: PackedVector3Array,capsules: Array[Dictionary],thickness: float,h: float,hinge: Vector3) -> Dictionary:
 var cloth_bounds := AABB(points[0],Vector3.ZERO)
 for p in points: cloth_bounds = cloth_bounds.expand(p)
 var count := 0
 var torque := Vector3.ZERO
 for capsule: Dictionary in capsules:
  var start: Vector3 = capsule.a
  var end: Vector3 = capsule.b
  var radius: float = capsule.radius+thickness
  var bounds := AABB(start,Vector3.ZERO).expand(end).grow(radius)
  if not bounds.intersects(cloth_bounds): continue
  for t in range(0,triangles.size(),3):
   var ids := [triangles[t],triangles[t+1],triangles[t+2]]
   var a := points[ids[0]]
   var b := points[ids[1]]
   var c := points[ids[2]]
   if not bounds.intersects(AABB(a,Vector3.ZERO).expand(b).expand(c)): continue
   var hit := nearest(a,b,c,start,end)
   if hit.distance>=radius: continue
   var bary: Vector3 = hit.bary
   var normal: Vector3 = hit.point-hit.axis
   if normal.length_squared()<EPS:
    # A capsule piercing the panel has no unique radial direction. Preserve the
    # preceding side of the panel instead of choosing a random normal.
    var old: Vector3 = previous[ids[0]]*bary.x+previous[ids[1]]*bary.y+previous[ids[2]]*bary.z
    var pair := closest_segments(old,old,start,end)
    normal = old-start.lerp(end,pair.y)
    if normal.length_squared()<EPS:
     normal = (b-a).cross(c-a)
    if normal.length_squared()<EPS: continue
   normal = normal.normalized()
   var denominator := 0.0
   for k in 3:
    if masses[ids[k]]>0: denominator += bary[k]*bary[k]/masses[ids[k]]
   if denominator<EPS: continue # Kinematic pins must be placed clear by the adapter.
   var correction: float = (radius-hit.distance)/denominator
   for k in 3:
    if masses[ids[k]]>0: points[ids[k]] += normal*(correction*bary[k]/masses[ids[k]])
   if capsule.get("yard",false): torque -= (hit.axis-hinge).cross(normal*correction/(h*h))
   count += 1
 return {"count":count,"yard_torque":torque}
