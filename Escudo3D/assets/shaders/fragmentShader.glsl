#version 330 core

out vec4 FragColor;

in VS_OUT
{
    vec3 FragPos;
    vec3 Normal;
    vec2 TexCoords;
    vec4 FragPosLightSpace;
} fs_in;

struct DirectionalLight
{
    vec3 direction;
    vec3 color;
    float intensity;
};

struct PointLight
{
    vec3 position;
    vec3 color;
    float intensity;
    float constant;
    float linear;
    float quadratic;
};

struct Material
{
    vec3 albedo;
    float metallic;
    float roughness;
    float ao;
};

uniform DirectionalLight dirLight;
uniform PointLight pointLight;
uniform Material material;

uniform vec3 viewPos;

uniform sampler2D shadowMap;
uniform bool useShadows;
uniform float shadowBias;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;

    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / max(denom, 0.000001);
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / max(denom, 0.000001);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);

    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float ShadowCalculation(vec4 fragPosLightSpace, vec3 normal, vec3 lightDir)
{
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    projCoords = projCoords * 0.5 + 0.5;

    if (projCoords.z > 1.0)
        return 0.0;

    float currentDepth = projCoords.z;
    float bias = max(shadowBias * (1.0 - dot(normal, lightDir)), shadowBias * 0.2);

    float shadow = 0.0;
    vec2 texelSize = 1.0 / textureSize(shadowMap, 0);

    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            float pcfDepth = texture(shadowMap, projCoords.xy + vec2(x, y) * texelSize).r;
            shadow += currentDepth - bias > pcfDepth ? 1.0 : 0.0;
        }
    }

    shadow /= 9.0;
    return shadow;
}

vec3 CalculatePBR(vec3 N, vec3 V, vec3 L, vec3 radiance, vec3 albedo, float metallic, float roughness)
{
    vec3 H = normalize(V + L);

    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo, metallic);

    float NDF = DistributionGGX(N, H, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    vec3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;

    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= (1.0 - metallic);

    float NdotL = max(dot(N, L), 0.0);

    return (kD * albedo / PI + specular) * radiance * NdotL;
}

void main()
{
    vec3 albedo = material.albedo;
    float metallic = clamp(material.metallic, 0.0, 1.0);
    float roughness = clamp(material.roughness, 0.05, 1.0);
    float ao = clamp(material.ao, 0.0, 1.0);

    vec3 N = normalize(fs_in.Normal);
    vec3 V = normalize(viewPos - fs_in.FragPos);

    vec3 Lo = vec3(0.0);

    // Luz direccional
    vec3 Ld = normalize(-dirLight.direction);
    vec3 radianceDir = dirLight.color * dirLight.intensity;

    float shadow = 0.0;
    if (useShadows)
        shadow = ShadowCalculation(fs_in.FragPosLightSpace, N, Ld);

    vec3 dirContribution = CalculatePBR(N, V, Ld, radianceDir, albedo, metallic, roughness);
    Lo += (1.0 - shadow) * dirContribution;

    // Luz puntual
    vec3 Lp = normalize(pointLight.position - fs_in.FragPos);
    float distance = length(pointLight.position - fs_in.FragPos);
    float attenuation = 1.0 / (pointLight.constant + pointLight.linear * distance + pointLight.quadratic * distance * distance);
    vec3 radiancePoint = pointLight.color * pointLight.intensity * attenuation;

    Lo += CalculatePBR(N, V, Lp, radiancePoint, albedo, metallic, roughness);

    // Ambiental
    vec3 ambient = vec3(0.03) * albedo * ao;

    vec3 color = ambient + Lo;

    // Tonemapping simple
    color = color / (color + vec3(1.0));

    // Gamma correction
    color = pow(color, vec3(1.0 / 2.2));

    FragColor = vec4(color, 1.0);
}