// modified version of https://www.shadertoy.com/view/wld3WN
// horizontal displacement magnitude of the rolling bar
#define BAR_DISPLACE .02
// bar thickness: closer to 1. = thinner/rarer, lower = thicker/more constant
#define BAR_THICKNESS .999
// vertical scroll speed of the bars
#define BAR_SPEED 1.6
// bar frequency: higher = more bars visible on screen at once
#define BAR_DENSITY 2.

// side-effects that only fire while a bar is passing
// chromatic aberration split (in uv units) at peak bar intensity
#define CHROMA .003
// white noise grain at peak bar intensity
#define GRAIN .15
// scanline modulation at peak bar intensity
#define SCANLINE .1

#define UI0 1597334673U
#define UI1 3812015801U
#define UI3 uvec3(UI0, UI1, 2798796415U)
#define UIF (1. / float(0xffffffffU))

vec3 hash33(vec3 p)
{
    uvec3 q = uvec3(ivec3(p)) * UI3;
    q = (q.x ^ q.y ^ q.z) * UI3;
    return -1. + 2. * vec3(q) * UIF;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;

    // two bars scrolling at different speeds, kicking the image in opposite directions
    float bar1 = smoothstep(BAR_THICKNESS, 1., sin((uv.y + t * BAR_SPEED) * BAR_DENSITY));
    float bar2 = smoothstep(BAR_THICKNESS, 1., sin((uv.y + t) * BAR_DENSITY));
    float distortion = (bar1 - bar2) * BAR_DISPLACE;

    // 0 when no bar present, 1 at a bar's peak — gates every extra effect below
    float barIntensity = max(bar1, bar2);

    // chromatic aberration, scaled by bar presence
    vec2 st = uv + vec2(distortion, 0.);
    vec2 eps = vec2(CHROMA * barIntensity, 0.);
    vec3 col;
    col.r = textureLod(iChannel0, st + eps, 0.).r;
    col.g = textureLod(iChannel0, st, 0.).g;
    col.b = textureLod(iChannel0, st - eps, 0.).b;

    // grain + scanline, only while a bar is passing
    float noise = hash33(vec3(fragCoord, mod(float(iFrame), 1000.))).r - .5;
    col += GRAIN * barIntensity * noise;
    col -= SCANLINE * barIntensity * sin(4. * t + uv.y * iResolution.y * 1.75);

    fragColor = vec4(col, 1.0);
}
