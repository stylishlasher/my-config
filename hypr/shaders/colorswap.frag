#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

vec3 rgb2hsv(vec3 c){
  vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
  vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
  vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
  float d = q.x - min(q.w, q.y);
  float e = 1.0e-10;
  return vec3(abs(q.z + (q.w - q.y)/(6.0*d + e)), d/(q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c){
  vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0))*6.0 - 3.0);
  return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
float cv(vec3 c){ return max(c.r, max(c.g, c.b)); }
float cs(vec3 c){ float mn = min(c.r, min(c.g, c.b)); float mx = cv(c); return (mx - mn) / (mx + 1.0e-5); }
float cl(vec3 c){ return dot(c, vec3(0.299, 0.587, 0.114)); }

void main(){
  vec4 px = texture(tex, v_texcoord);
  vec3 hsv = rgb2hsv(px.rgb);
  float h0 = hsv.x;
  float w0 = smoothstep(0.08, 0.25, hsv.y) * smoothstep(0.04, 0.15, hsv.z);
  float dh = 0.0, sm = 1.0, vm = 1.0;
  { float d = abs(fract(h0 - 0.33333 + 0.5) - 0.5);
    float m = (1.0 - smoothstep(0.04167, 0.08333, d)) * w0;
    dh += m * 0.33333; sm *= mix(1.0, 1.0000, m); vm *= mix(1.0, 1.0000, m); }

  hsv.x = fract(h0 + dh);
  hsv.y = clamp(hsv.y * sm, 0.0, 1.0);
  hsv.z = clamp(hsv.z * vm, 0.0, 1.0);
  vec3 col = hsv2rgb(hsv);

  fragColor = vec4(clamp(col, 0.0, 1.0), px.a);
}
