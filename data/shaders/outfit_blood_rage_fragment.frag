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

    // Subtle global pulse effect (not moving wave)
    float globalPulse = sin(u_Time * 1.8) * 0.5 + 0.5;
    
    // Veins that subtly animate with position-based variation
    float veinPattern = sin(v_TexCoord.y * 12.0) * 0.5 + 0.5;
    veinPattern *= sin(v_TexCoord.x * 8.0) * 0.5 + 0.5;
    
    // Combine for elegant vein pulsing
    float pulse = mix(0.3, 0.7, globalPulse);
    float veinIntensity = mix(veinPattern, globalPulse, 0.6);

    // Darker, more elegant blood colors
    vec3 bloodDark = vec3(0.25, 0.01, 0.01);
    vec3 bloodVein = vec3(0.75, 0.05, 0.05);
    vec3 bloodBright = vec3(0.95, 0.15, 0.15);

    // Apply subtle darkening
    vec3 darkened = max(base.rgb - (bloodDark * 0.3), vec3(0.0));
    
    // Vein mask with smooth transitions
    float veinMask = smoothstep(0.4, 0.8, veinIntensity);
    
    // Blend: mostly darkened, with veins pulsing in
    float blendFactor = clamp(0.12 + pulse * 0.18 + veinMask * 0.25, 0.0, 0.5);
    vec3 finalColor = mix(darkened, mix(bloodVein, bloodBright, pulse), blendFactor);
    
    gl_FragColor = vec4(finalColor, base.a);
}