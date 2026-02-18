// Magical Item Vertex Shader
// Standard vertex transformation for magical item glow effect

attribute vec2 a_TexCoord;
attribute vec2 a_Vertex;

uniform mat3 u_TextureMatrix;
uniform mat3 u_TransformMatrix;
uniform mat3 u_ProjectionMatrix;

varying vec2 v_TexCoord;

void main()
{
    v_TexCoord = (u_TextureMatrix * vec3(a_TexCoord, 1.0)).xy;
    gl_Position = vec4((u_ProjectionMatrix * u_TransformMatrix * vec3(a_Vertex.xy, 1.0)).xy, 1.0, 1.0);
}
