shader_type sky;
uniform float clock=0.0;
uniform float daylight=1.0;
uniform float cloud_cover=0.4;
uniform float storminess=0.0;
uniform float flash=0.0;
uniform vec2 wind=vec2(0.0,1.0);
uniform vec3 sun_direction=vec3(0.0,1.0,0.0);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
float fbm(vec2 p) {return noise(p)*0.53+noise(p*2.03+4.7)*0.27+noise(p*4.17-8.1)*0.13+noise(p*8.31)*0.07;}
void sky() {
 vec3 d=normalize(EYEDIR);
 float altitude=max(0.0,d.y);
 vec3 day=mix(vec3(0.48,0.64,0.72),vec3(0.075,0.28,0.53),pow(altitude,0.45));
 day=mix(day,vec3(0.24,0.30,0.36),storminess*0.72);
 vec3 night=mix(vec3(0.026,0.044,0.075),vec3(0.006,0.013,0.037),altitude);
 vec3 color=mix(night,day,daylight);
 vec2 p=d.xz/max(0.16,d.y)*1.6-wind*clock*0.0006;
 float mass=fbm(p);
 float clouds=smoothstep(0.78-cloud_cover*0.49,0.94-cloud_cover*0.46,mass)*smoothstep(0.0,0.12,d.y);
 vec3 cloud_color=mix(vec3(0.81,0.84,0.85),vec3(0.19,0.24,0.29),storminess);
 cloud_color*=mix(0.16,1.0,daylight)*(0.74+mass*0.26);
 color=mix(color,cloud_color,clouds);
 float sun_dot=max(0.0,dot(d,sun_direction));
 color+=vec3(1.0,0.87,0.63)*(pow(sun_dot,800.0)*2.0+pow(sun_dot,28.0)*0.12)*daylight*(1.0-clouds);
 float moon_dot=max(0.0,dot(d,-sun_direction));
 color+=vec3(0.55,0.66,0.82)*pow(moon_dot,1800.0)*(1.0-daylight)*(1.0-clouds);
 vec2 stars=d.xz/max(0.08,d.y)*180.0;
 float star=step(0.997,hash(floor(stars)))*(1.0-smoothstep(0.0,0.08,length(fract(stars)-0.5)));
 color+=star*(1.0-daylight)*(1.0-clouds)*smoothstep(0.0,0.2,d.y);
 COLOR=color+vec3(0.40,0.46,0.55)*flash;
}
