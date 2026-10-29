shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform float clock=0.0;
uniform float amount=0.0;
uniform vec2 wind=vec2(0.0);
varying float visible_drop;
void vertex() {
 vec3 center=vec3((INSTANCE_CUSTOM.r-0.5)*38.0,mod(INSTANCE_CUSTOM.g*25.0-clock*15.0,25.0),(INSTANCE_CUSTOM.b-0.5)*38.0);
 VERTEX.xz+=wind*VERTEX.y*0.05;
 VERTEX+=center;
 visible_drop=step(INSTANCE_CUSTOM.a,amount)*smoothstep(1.8,3.5,length(center-vec3(0.0,1.0,0.0)));
}
void fragment() { ALBEDO=vec3(0.62,0.71,0.78);ALPHA=visible_drop*0.28*(1.0-abs(UV.y-0.5)*1.5); }
