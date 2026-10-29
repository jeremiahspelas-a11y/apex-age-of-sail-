extends RefCounted
## Thin, two-sided cloth using the existing sail span, drop and measured head position.
const COLUMNS := 16
const ROWS := 12
static func build(bounds: AABB, head_z: float) -> ArrayMesh:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 st.set_smooth_group(0)
 for row in ROWS:
  for column in COLUMNS:
   var u0 := float(column)/COLUMNS
   var u1 := float(column+1)/COLUMNS
   var v0 := float(row)/ROWS
   var v1 := float(row+1)/ROWS
   for uv: Vector2 in [Vector2(u0,v0),Vector2(u1,v1),Vector2(u1,v0),Vector2(u0,v0),Vector2(u0,v1),Vector2(u1,v1)]:
    var u := uv.x
    var v := uv.y
    var width := bounds.size.x*lerpf(1.0,0.88,v)
    var x := bounds.get_center().x+(u-0.5)*width
    var y := bounds.end.y-v*bounds.size.y + sin(u*PI)*pow(v,4.0)*bounds.size.y*0.075
    var camber := minf(0.78,bounds.size.x*0.065)
    var z := head_z-0.55*v-camber*sin(u*PI)*sin(v*PI)
    st.set_uv(uv)
    st.add_vertex(Vector3(x,y,z))
 st.generate_normals()
 st.index()
 return st.commit()
