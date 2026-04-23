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

    // Slower corruption pulse with denser tint.
    float waveA = sin(u_Time * 1.7 + v_TexCoord.y * 8.0) * 0.5 + 0.5;
    float waveB = sin(u_Time * 0.9 + v_TexCoord.x * 5.0) * 0.5 + 0.5;
    float wave = (waveA * 0.7) + (waveB * 0.3);
    float pulse = wave * 0.45 + 0.35;

    // Dark component + denser violet core.
    vec3 corruptedDark = vec3(0.23, 0.03, 0.30);
    vec3 corruptedCore = vec3(0.34, 0.05, 0.45);

    vec3 darkened = max(base.rgb - (corruptedDark * pulse * 0.95), vec3(0.0));
    float blendFactor = clamp(0.28 + pulse * 0.30, 0.0, 0.75);
    vec3 finalColor = mix(darkened, corruptedCore, blendFactor);
    gl_FragColor = vec4(finalColor, base.a);
}
