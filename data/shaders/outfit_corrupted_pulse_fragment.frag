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

    // Stronger, more visible corruption pulse.
    float waveA = sin(u_Time * 4.2 + v_TexCoord.y * 10.0) * 0.5 + 0.5;
    float waveB = sin(u_Time * 2.1 + v_TexCoord.x * 7.0) * 0.5 + 0.5;
    float wave = (waveA * 0.7) + (waveB * 0.3);
    float pulse = wave * 0.65 + 0.20;

    // Dark component + emissive violet component for clear readability.
    vec3 corruptedDark = vec3(0.32, 0.06, 0.40);
    vec3 corruptedGlow = vec3(0.56, 0.10, 0.72);

    vec3 darkened = max(base.rgb - (corruptedDark * pulse * 0.75), vec3(0.0));
    vec3 finalColor = darkened + (corruptedGlow * pulse * 0.45);
    gl_FragColor = vec4(finalColor, base.a);
}
