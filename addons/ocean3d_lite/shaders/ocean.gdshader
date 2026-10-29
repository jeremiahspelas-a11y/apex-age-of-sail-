shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform vec3 waves[16];
uniform float phases[16];
uniform float t = 0.0;
uniform float storm_scale = 1.0;
uniform float choppiness = 0.5;
uniform vec2 wind_direction = vec2(0.0,1.0);
uniform float wind_speed = 8.0;
uniform float storminess = 0.0;
uniform vec2 ship_position = vec2(0.0);
uniform vec2 ship_forward = vec2(0.0,-1.0);
uniform float ship_speed = 0.0;
varying vec2 sea_world;
varying float compression;
varying float older_compression;
varying float elevation;
vec3 envelope(int i,vec2 p,float clock) {
 float index=float(i);
 float angle=radians(23.0+index*41.0);
 vec2 d=vec2(cos(angle),sin(angle));
 vec2 cross_d=vec2(-d.y,d.x);
 float k=0.009+index*0.0007;
 float a=dot(d,p)*k-clock*(0.065+index*0.004)+index*1.71;
 float b=dot(cross_d,p)*0.021+clock*0.053+index*2.31;
 vec2 gradient=d*(0.25*cos(a)*k)+cross_d*(0.13*cos(b)*0.021);
 return vec3(0.72+0.25*sin(a)+0.13*sin(b),gradient);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 vec2 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 vec3 displacement=vec3(0.0);
 vec3 dx=vec3(1,0,0); vec3 dz=vec3(0,0,1);
 vec2 old_dx=vec2(1,0); vec2 old_dz=vec2(0,1);
 for(int i=0;i<16;i++) {
  vec2 d=vec2(cos(radians(waves[i].x)),sin(radians(waves[i].x)));
  float k=6.28318530718/waves[i].z;
  float omega=sqrt(9.8*k);
  float phase=k*dot(d,p)-omega*t+phases[i];
  vec3 env=envelope(i,p,t);
  float a=waves[i].y*storm_scale*env.x;
  vec2 da=waves[i].y*storm_scale*env.yz;
  float s=sin(phase); float c=cos(phase);
  displacement+=vec3(d.x*choppiness*a*c,a*s,d.y*choppiness*a*c);
  float x_term=da.x*c-a*s*k*d.x;
  float z_term=da.y*c-a*s*k*d.y;
  dx+=vec3(d.x*choppiness*x_term,da.x*s+a*c*k*d.x,d.y*choppiness*x_term);
  dz+=vec3(d.x*choppiness*z_term,da.y*s+a*c*k*d.y,d.y*choppiness*z_term);
  // Short-lived residual froth from a previous compression event, not height bands.
  float old_phase=phase+omega*1.5;
  float old_x=da.x*cos(old_phase)-a*sin(old_phase)*k*d.x;
  float old_z=da.y*cos(old_phase)-a*sin(old_phase)*k*d.y;
  old_dx+=d*choppiness*old_x; old_dz+=d*choppiness*old_z;
 }
 VERTEX+=displacement;
 NORMAL=normalize(cross(dz,dx));
 compression=1.0-(dx.x*dz.z-dx.z*dz.x);
 older_compression=1.0-(old_dx.x*old_dz.y-old_dx.y*old_dz.x);
 sea_world=p+displacement.xz;
 elevation=displacement.y;
}
void fragment() {
 vec2 advected=sea_world-wind_direction*t*0.65;
 float broad=noise(advected*0.32)+noise(advected*0.77)*0.4;
 float bubbles=noise(advected*3.1+noise(advected*0.8));
 float wind_gate=smoothstep(3.0,9.0,wind_speed);
 float breaker=smoothstep(0.11,0.32,compression)*smoothstep(0.40,0.95,broad)*wind_gate;
 float remnant=smoothstep(0.14,0.34,older_compression)*smoothstep(0.64,1.18,broad)*0.4*wind_gate;
 float foam=max(breaker,remnant)*(0.6+0.4*bubbles);
 // Coarse horizon geometry must not stretch sampled crest values into white bars.
 float distance_to_eye=length(sea_world-CAMERA_POSITION_WORLD.xz);
 foam*=1.0-smoothstep(70.0,125.0,distance_to_eye);
 vec2 aft=sea_world-ship_position;
 vec2 heading=normalize(ship_forward+vec2(0.00001));
 float behind=-dot(aft,heading);
 float lateral=abs(heading.x*aft.y-heading.y*aft.x);
 float edges=1.0-smoothstep(0.2,1.3,abs(lateral-(2.1+behind*0.22)));
 float wake_length=smoothstep(9.0,14.0,behind)*(1.0-smoothstep(28.0,65.0,behind));
 float wake=edges*wake_length*clamp(ship_speed/5.0,0.0,0.8)*smoothstep(0.22,0.72,broad);
 float bow=exp(-pow((behind+12.0)/1.5,2.0))*exp(-pow((lateral-1.4)/1.2,2.0))*clamp(ship_speed/4.0,0.0,0.6);
 foam=clamp(max(foam,max(wake,bow)),0.0,0.92);
 float glint=noise(sea_world*1.5+wind_direction*t*0.3)-0.5;
 vec3 deep=vec3(0.018,0.095,0.13);
 vec3 lit=vec3(0.035,0.19,0.22);
 ALBEDO=mix(deep,lit,clamp(0.40+elevation*0.10+glint*0.12,0.0,1.0));
 ALBEDO=mix(ALBEDO,vec3(0.63,0.73,0.71),foam);
 ROUGHNESS=mix(0.54,0.95,foam)+storminess*0.03;
 SPECULAR=0.28;
 METALLIC=0.0;
}
