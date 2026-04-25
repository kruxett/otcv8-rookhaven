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

    float waveA = sin(u_Time * 2.35 + v_TexCoord.y * 8.2) * 0.5 + 0.5;
    float waveB = sin(u_Time * 1.45 + v_TexCoord.x * 5.8) * 0.5 + 0.5;
    float wave = (waveA * 0.62) + (waveB * 0.38);
    float pulse = wave * 0.52 + 0.22;

    vec3 bloodDark = vec3(0.30, 0.02, 0.02);
    vec3 bloodVein = vec3(0.82, 0.08, 0.08);

    vec3 darkened = max(base.rgb - (bloodDark * (0.50 + pulse * 0.50)), vec3(0.0));
    float veinMask = smoothstep(0.68, 0.95, waveA * waveB);
    float blendFactor = clamp(0.16 + pulse * 0.28 + veinMask * 0.34, 0.0, 0.74);
    vec3 finalColor = mix(darkened, bloodVein, blendFactor);
    gl_FragColor = vec4(finalColor, base.a);
}