#pragma once

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

struct DirectionalLight
{
    glm::vec3 direction = glm::vec3(-0.2f, -1.0f, -0.3f);
    glm::vec3 color = glm::vec3(1.0f, 1.0f, 1.0f);
    float intensity = 2.0f;
};

struct PointLight
{
    glm::vec3 position = glm::vec3(2.0f, 2.0f, 2.0f);
    glm::vec3 color = glm::vec3(1.0f, 0.95f, 0.85f);
    float intensity = 30.0f;

    float constant = 1.0f;
    float linear = 0.09f;
    float quadratic = 0.032f;
};

class Lighting
{
public:
    DirectionalLight sun;
    PointLight detailLight;

    bool shadowsEnabled = true;
    float shadowBias = 0.005f;

    glm::mat4 lightProjection = glm::mat4(1.0f);
    glm::mat4 lightView = glm::mat4(1.0f);
    glm::mat4 lightSpaceMatrix = glm::mat4(1.0f);

    Lighting();

    void setupDefaultLights();
    void updateLightSpaceMatrix(const glm::vec3& sceneCenter = glm::vec3(0.0f));

    void apply(GLuint shaderProgram, const glm::vec3& viewPos) const;
    void bindShadowMap(GLuint shaderProgram, GLuint depthMapTexture, GLuint textureUnit = 5) const;
};