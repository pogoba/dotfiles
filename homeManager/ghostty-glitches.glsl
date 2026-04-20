// modified version of https://www.shadertoy.com/view/wld3WN
// horizontal displacement magnitude of the rolling bar
#define BAR_DISPLACE .02
// bar thickness: closer to 1. = thinner/rarer, lower = thicker/more constant
#define BAR_THICKNESS .999
// bar pointiness: 1. = original flat-topped slab, higher = sharper peak with faster shoulder drop-off
#define BAR_POINTINESS 3.
// vertical scroll speed of the primary bar during its sweep
#define BAR_SPEED 1.6
// secondary bar's speed — different from BAR_SPEED so the two sweeps drift out of sync
#define BAR_SPEED_2 1.
// bar frequency: higher = more bars visible on screen at once
#define BAR_DENSITY 2.
// break multiplier: 1. = always-on (original cadence), 10. → bar appears only 1 in every 10 natural periods
#define BREAK_MULTIPLIER 100.
// halo spread around the bar: lower = much wider taper. 0. covers ~the whole screen when the bar is centered
#define HALO_THICKNESS 0.

// side-effects that travel with the bar, tapered by the halo
// chromatic aberration split (in uv units) at halo peak
#define CHROMA .002
// white noise grain at halo peak
#define GRAIN .00
// scanline modulation at peak bar intensity (stays local to the bar core)
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

    // two bars scrolling at their full speeds, continuous like the original
    float s1 = sin((uv.y + t * BAR_SPEED) * BAR_DENSITY);
    float s2 = sin((uv.y + t * BAR_SPEED_2) * BAR_DENSITY);

    // each bar is active for one natural period out of every BREAK_MULTIPLIER.
    // at BREAK_MULTIPLIER=1 the gate is always open (matches the original exactly).
    float period1 = 6.2831853 / (BAR_SPEED   * BAR_DENSITY);
    float period2 = 6.2831853 / (BAR_SPEED_2 * BAR_DENSITY);
    float active1 = step(mod(t, period1 * BREAK_MULTIPLIER), period1);
    float active2 = step(mod(t, period2 * BREAK_MULTIPLIER), period2);

    float bar1 = pow(smoothstep(BAR_THICKNESS, 1., s1), BAR_POINTINESS) * active1;
    float bar2 = pow(smoothstep(BAR_THICKNESS, 1., s2), BAR_POINTINESS) * active2;
    float distortion = (bar1 - bar2) * BAR_DISPLACE;

    // thin core — for the hard pixel-shift and scanline flash
    float barIntensity = max(bar1, bar2);

    // wide halo that travels with the bar, tapering out above and below (also gated)
    float haloIntensity = max(smoothstep(HALO_THICKNESS, 1., s1) * active1,
                              smoothstep(HALO_THICKNESS, 1., s2) * active2);

    // chromatic aberration, tapered by the halo around the bar
    vec2 st = uv + vec2(distortion, 0.);
    vec2 eps = vec2(CHROMA * haloIntensity, 0.);
    vec3 col;
    col.r = textureLod(iChannel0, st + eps, 0.).r;
    col.g = textureLod(iChannel0, st, 0.).g;
    col.b = textureLod(iChannel0, st - eps, 0.).b;

    // grain also tapers with the halo; scanline stays tight to the bar core
    float noise = hash33(vec3(fragCoord, mod(float(iFrame), 1000.))).r - .5;
    col += GRAIN * haloIntensity * noise;
    col -= SCANLINE * barIntensity * sin(4. * t + uv.y * iResolution.y * 1.75);

    fragColor = vec4(col, 1.0);
}
