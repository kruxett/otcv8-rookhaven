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

    // Subtler corruption pulse: darker taint, less glow-like energy.
    float waveA = sin(u_Time * 2.1 + v_TexCoord.y * 8.0) * 0.5 + 0.5;
    float waveB = sin(u_Time * 1.2 + v_TexCoord.x * 5.4) * 0.5 + 0.5;
    float wave = (waveA * 0.65) + (waveB * 0.35);
    float pulse = wave * 0.45 + 0.20;

    // Dark corruption veil + muted violet veins (non-additive).
    vec3 corruptedDark = vec3(0.22, 0.04, 0.28);
    vec3 corruptedVein = vec3(0.42, 0.12, 0.52);

    vec3 darkened = max(base.rgb - (corruptedDark * (0.55 + pulse * 0.45)), vec3(0.0));
    float veinMask = smoothstep(0.72, 0.96, waveA * waveB);
    float blendFactor = clamp(0.18 + pulse * 0.24 + veinMask * 0.28, 0.0, 0.62);
    vec3 finalColor = mix(darkened, corruptedVein, blendFactor);
    gl_FragColor = vec4(finalColor, base.a);
}
