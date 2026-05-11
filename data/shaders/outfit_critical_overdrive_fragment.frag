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

    // Clean premium crit flash: warm gold core + soft pearl sheen.
    float pulse = sin(u_Time * 8.5) * 0.5 + 0.5;
    float sheenWave = sin((v_TexCoord.x * 1.35 + v_TexCoord.y * 0.95) * 6.0 - u_Time * 5.5) * 0.5 + 0.5;
    float sheen = smoothstep(0.60, 0.96, sheenWave);

    float edge = smoothstep(0.72, 0.18, distance(v_TexCoord, vec2(0.5, 0.5)));
    float intensity = clamp(0.16 + pulse * 0.30 + sheen * 0.22 + edge * 0.16, 0.0, 0.72);

    vec3 shadow = vec3(0.20, 0.11, 0.03);
    vec3 gold = vec3(1.00, 0.76, 0.24);
    vec3 pearl = vec3(1.00, 0.96, 0.86);

    vec3 softened = max(base.rgb - (shadow * 0.18), vec3(0.0));
    vec3 premium = mix(gold, pearl, pulse * 0.45 + sheen * 0.55);
    vec3 finalColor = mix(softened, premium, intensity);

    gl_FragColor = vec4(finalColor, base.a);
}
