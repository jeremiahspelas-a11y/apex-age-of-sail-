uniform vec4 base_color : source_color = vec4(0.45,0.29,0.16,1.0);
uniform int surface_kind = 0; // timber, deck, hull, hemp, iron, canvas
uniform int grain_axis = 2;
uniform float wetness : hint_range(0.0,1.0) = 0.0;
uniform float wind_strength : hint_range(0.0,1.0) = 0.5;
uniform bool cloth_flutter = true;
uniform sampler2D timber_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D canvas_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D hemp_map : filter_linear_mipmap, repeat_enable;
varying vec3 timber_position;
// Derivative bump works on imported and procedural surfaces without a tangent stream.
vec3 bump_normal(vec3 normal, vec3 position, float height) {
 vec3 dx = dFdx(position);
 vec3 dy = dFdy(position);
 vec3 rx = cross(dy,normal);
 vec3 ry = cross(normal,dx);
 float det = dot(dx,rx);
 return normalize(abs(det)*normal-sign(det)*(dFdx(height)*rx+dFdy(height)*ry));
}
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float seam(float value, float width) {
 float edge = min(fract(value),1.0-fract(value));
 return 1.0-smoothstep(width,width*2.5,edge);
}
void vertex() {
 timber_position = VERTEX;
 if (surface_kind == 5 && cloth_flutter) {
  // Small leech flutter; the entire head stays pinned to the measured yard.
  VERTEX.z += sin(TIME*1.7+UV.x*11.0+UV.y*7.0)*0.025*wind_strength*UV.y*UV.y*sin(UV.x*3.14159265);
 }
}
void fragment() {
 vec3 p = timber_position;
 vec3 color = base_color.rgb;
 float roughness = 0.83;
 float relief = 0.0;
 METALLIC = 0.0;
 if (surface_kind == 5) {
  if (!FRONT_FACING) { NORMAL = -NORMAL; }
  float panels = seam(UV.x*12.0,0.012);
  float weave_fade = 1.0-smoothstep(0.2,0.65,max(fwidth(UV.x*400.0),fwidth(UV.y*300.0)));
  float weave = sin(UV.x*400.0)*sin(UV.y*300.0)*0.008*weave_fade;
  float linen = texture(canvas_map,UV*vec2(3.0,2.0)).r;
  float edge = max(seam(UV.x,0.012),seam(UV.y,0.014));
  float stitching = seam(UV.x*12.0+0.018,0.006)*step(0.5,fract(UV.y*95.0));
  float weathering = (0.77+linen*0.29)-0.10*UV.y + weave;
  weathering *= 1.0-edge*0.14-stitching*0.15;
  relief = linen*0.0015+panels*0.002;
  color *= weathering*(1.0-panels*0.12);
  roughness = 0.96;
  BACKLIGHT = base_color.rgb*0.18;
 } else if (surface_kind == 4) {
  color *= 0.92+0.08*hash21(floor(p.xy*70.0));
  roughness = 0.52;
  METALLIC = 0.65;
 } else if (surface_kind == 3) {
  float twist = sin((p.x+p.z)*80.0+p.y*18.0);
  float fiber = texture(hemp_map,vec2(p.y+p.z,p.x)*3.0).r;
  color *= 0.65+0.42*fiber+0.08*twist;
  relief = fiber*0.002;
  roughness = 0.96;
 } else {
  float along = p.z;
  float across = p.x;
  if (grain_axis == 0) { along=p.x; across=p.y; }
  if (grain_axis == 1) { along=p.y; across=p.x; }
  if (surface_kind == 2) { along=p.z; across=p.y; }
  float grain = sin(across*110.0+sin(along*1.9+across*9.0)*2.1)*0.025;
  grain += sin(across*241.0+sin(along*0.7)*4.0)*0.012;
  float variation = 1.0;
  if (surface_kind == 1 || surface_kind == 2) {
   float plank_width = surface_kind == 1 ? 0.24 : 0.28;
   float row = across/plank_width;
   float stagger = mod(floor(row),3.0)*1.20;
   float plank = floor((along+stagger)/3.60);
   variation = 0.90+hash21(vec2(floor(row),plank))*0.16;
   float caulk = max(seam(row,0.008),seam((along+stagger)/3.60,0.001));
   color *= mix(variation,0.35,caulk*0.75);
  }
  float timber = texture(timber_map,vec2(along*0.32,across*0.8)).r;
  color *= 0.61+timber*0.58+grain;
  relief = timber*0.004;
 }
 NORMAL = bump_normal(NORMAL,VERTEX,relief);
 ALBEDO = color*mix(1.0,0.84,wetness);
 ROUGHNESS = mix(roughness,max(0.32,roughness*0.64),wetness);
 SPECULAR = surface_kind == 4 ? 0.5 : 0.24;
}
