uniform mat4 u_Color;
varying vec2 v_TexCoord;
varying vec2 v_TexCoord2;
uniform sampler2D u_Tex0;
uniform float u_Time;

void main()
{
    vec4 base = texture2D(u_Tex0, v_TexCoord);
    vec4 texcolor = texture2D(u_Tex0, v_TexCoord2);

    if (texcolor.r > 0.9) {
        base *= texcolor.g > 0.9 ? u_Color[0] : u_Color[1];
    } else if (texcolor.g > 0.9) {
        base *= u_Color[2];
    } else if (texcolor.b > 0.9) {
        base *= u_Color[3];
    }

    if (base.a < 0.01) {
        discard;
    }

    // Calm fortified pulse with soft directional shimmer.
    float pulse = sin(u_Time * 1.5) * 0.5 + 0.5;
    float sweep = sin((v_TexCoord.x + v_TexCoord.y) * 9.0 - u_Time * 2.0) * 0.5 + 0.5;
    float lattice = sin(v_TexCoord.x * 14.0) * sin(v_TexCoord.y * 10.0) * 0.5 + 0.5;

    float shieldMask = smoothstep(0.45, 0.92, (sweep * 0.65) + (lattice * 0.35));
    float glow = clamp(0.10 + pulse * 0.22 + shieldMask * 0.28, 0.0, 0.58);

    vec3 goldShadow = vec3(0.20, 0.15, 0.03);
    vec3 goldCore = vec3(0.87, 0.72, 0.18);
    vec3 goldHighlight = vec3(1.00, 0.90, 0.42);

    vec3 darkened = max(base.rgb - (goldShadow * (0.45 + pulse * 0.25)), vec3(0.0));
    vec3 fortified = mix(goldCore, goldHighlight, pulse * 0.6 + shieldMask * 0.4);
    vec3 finalColor = mix(darkened, fortified, glow);

    gl_FragColor = vec4(finalColor, base.a);
}
