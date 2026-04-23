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

    // Subtle dark-violet pulse to signal corruption.
    float wave = sin(u_Time * 3.0 + v_TexCoord.y * 9.0) * 0.5 + 0.5;
    float pulse = wave * 0.28 + 0.06;
    vec3 corruptedTint = vec3(0.26, 0.05, 0.33);

    vec3 finalColor = max(base.rgb - (corruptedTint * pulse), vec3(0.0));
    gl_FragColor = vec4(finalColor, base.a);
}
