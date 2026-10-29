extends RefCounted
## Visible bolt ropes and head lashings follow the sail mesh. Cosmetic, not new constraints.
const Refit = preload("res://scripts/ship_refit.gd")
static func build(sail_mesh: Mesh,head_loop_offset: Vector3 = Vector3.ZERO) -> ArrayMesh:
 var arrays := sail_mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var sides: Array[Array] = [[],[],[],[]]
 var unique: Dictionary = {}
 for i in vertices.size():
  var uv := uvs[i]
  var key := "%.5f/%.5f"%[uv.x,uv.y]
  if unique.has(key): continue
  unique[key] = true
  if uv.y<0.0001: sides[0].append({"t":uv.x,"p":vertices[i]})
  if uv.y>0.9999: sides[1].append({"t":uv.x,"p":vertices[i]})
  if uv.x<0.0001: sides[2].append({"t":uv.y,"p":vertices[i]})
  if uv.x>0.9999: sides[3].append({"t":uv.y,"p":vertices[i]})
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 for side: Array in sides:
  side.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.t<b.t)
  for i in range(side.size()-1): Refit._tube(st,side[i].p,side[i+1].p,0.014)
 for item: Dictionary in sides[0]:
  var p: Vector3 = item.p+head_loop_offset
  for k in 8:
   var a := float(k)/8.0*TAU
   var b := float(k+1)/8.0*TAU
   Refit._tube(st,p+Vector3(0,sin(a),cos(a))*0.12,p+Vector3(0,sin(b),cos(b))*0.12,0.008)
 st.generate_normals()
 st.index()
 return st.commit()
