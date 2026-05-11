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

    // Fast impact pulse with diagonal shock pattern.
    float impact = sin(u_Time * 10.0) * 0.5 + 0.5;
    float diagonal = sin((v_TexCoord.x - v_TexCoord.y) * 20.0 + u_Time * 18.0) * 0.5 + 0.5;
    float radial = sin(length(v_TexCoord - vec2(0.5, 0.5)) * 34.0 - u_Time * 22.0) * 0.5 + 0.5;

    float streak = smoothstep(0.58, 0.95, diagonal);
    float burst = smoothstep(0.45, 0.92, radial);
    float intensity = clamp(0.12 + impact * 0.30 + streak * 0.24 + burst * 0.24, 0.0, 0.78);

    vec3 shadow = vec3(0.25, 0.05, 0.02);
    vec3 core = vec3(1.00, 0.34, 0.08);
    vec3 highlight = vec3(1.00, 0.85, 0.30);

    vec3 darkened = max(base.rgb - (shadow * (0.35 + impact * 0.25)), vec3(0.0));
    vec3 energized = mix(core, highlight, impact * 0.55 + streak * 0.45);
    vec3 finalColor = mix(darkened, energized, intensity);

    gl_FragColor = vec4(finalColor, base.a);
}
