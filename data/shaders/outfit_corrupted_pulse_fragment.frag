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

    // Stronger corruption pulse tuned for readability in normal gameplay.
    float waveA = sin(u_Time * 2.8 + v_TexCoord.y * 9.5) * 0.5 + 0.5;
    float waveB = sin(u_Time * 1.6 + v_TexCoord.x * 6.5) * 0.5 + 0.5;
    float wave = (waveA * 0.7) + (waveB * 0.3);
    float pulse = wave * 0.60 + 0.25;

    // Dark component + vivid violet core + mild emissive boost.
    vec3 corruptedDark = vec3(0.30, 0.06, 0.38);
    vec3 corruptedCore = vec3(0.58, 0.14, 0.74);
    vec3 corruptedGlow = vec3(0.44, 0.10, 0.58);

    vec3 darkened = max(base.rgb - (corruptedDark * pulse * 0.80), vec3(0.0));
    float blendFactor = clamp(0.40 + pulse * 0.36, 0.0, 0.92);
    vec3 finalColor = mix(darkened, corruptedCore, blendFactor) + (corruptedGlow * pulse * 0.18);
    gl_FragColor = vec4(finalColor, base.a);
}
