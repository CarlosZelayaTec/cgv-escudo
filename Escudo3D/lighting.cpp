#include "lighting.h"
#include <string>

static void setUniformVec3(GLuint program, const char* name, const glm::vec3& value)
{
    glUniform3fv(glGetUniformLocation(program, name), 1, &value[0]);
}

static void setUniformFloat(GLuint program, const char* name, float value)
{
    glUniform1f(glGetUniformLocation(program, name), value);
}

static void setUniformInt(GLuint program, const char* name, int value)
{
    glUniform1i(glGetUniformLocation(program, name), value);
}

static void setUniformMat4(GLuint program, const char* name, const glm::mat4& mat)
{
    glUniformMatrix4fv(glGetUniformLocation(program, name), 1, GL_FALSE, &mat[0][0]);
}

Lighting::Lighting()
{
    setupDefaultLights();
    updateLightSpaceMatrix();
}

void Lighting::setupDefaultLights()
{
    // Sol principal
    sun.direction = glm::normalize(glm::vec3(-0.4f, -1.0f, -0.35f));
    sun.color = glm::vec3(1.0f, 0.98f, 0.95f);
    sun.intensity = 2.2f;

    // Luz puntual para resaltar detalles del escudo
    detailLight.position = glm::vec3(2.5f, 2.0f, 2.5f);
    detailLight.color = glm::vec3(1.0f, 0.95f, 0.85f);
    detailLight.intensity = 28.0f;

    detailLight.constant = 1.0f;
    detailLight.linear = 0.09f;
    detailLight.quadratic = 0.032f;

    shadowsEnabled = true;
    shadowBias = 0.005f;
}

void Lighting::updateLightSpaceMatrix(const glm::vec3& sceneCenter)
{
    // Ajusta esto según el tamaño real de la escena
    lightProjection = glm::ortho(-10.0f, 10.0f, -10.0f, 10.0f, 1.0f, 25.0f);

    glm::vec3 lightPos = sceneCenter - sun.direction * 8.0f;
    lightView = glm::lookAt(
        lightPos,
        sceneCenter,
        glm::vec3(0.0f, 1.0f, 0.0f)
    );

    lightSpaceMatrix = lightProjection * lightView;
}

void Lighting::apply(GLuint shaderProgram, const glm::vec3& viewPos) const
{
    glUseProgram(shaderProgram);

    setUniformVec3(shaderProgram, "viewPos", viewPos);

    // Luz direccional
    setUniformVec3(shaderProgram, "dirLight.direction", sun.direction);
    setUniformVec3(shaderProgram, "dirLight.color", sun.color);
    setUniformFloat(shaderProgram, "dirLight.intensity", sun.intensity);

    // Luz puntual
    setUniformVec3(shaderProgram, "pointLight.position", detailLight.position);
    setUniformVec3(shaderProgram, "pointLight.color", detailLight.color);
    setUniformFloat(shaderProgram, "pointLight.intensity", detailLight.intensity);
    setUniformFloat(shaderProgram, "pointLight.constant", detailLight.constant);
    setUniformFloat(shaderProgram, "pointLight.linear", detailLight.linear);
    setUniformFloat(shaderProgram, "pointLight.quadratic", detailLight.quadratic);

    // Sombras
    setUniformInt(shaderProgram, "useShadows", shadowsEnabled ? 1 : 0);
    setUniformFloat(shaderProgram, "shadowBias", shadowBias);
    setUniformMat4(shaderProgram, "lightSpaceMatrix", lightSpaceMatrix);

    // Material por defecto PBR simplificado
    setUniformVec3(shaderProgram, "material.albedo", glm::vec3(0.75f, 0.75f, 0.75f));
    setUniformFloat(shaderProgram, "material.metallic", 0.15f);
    setUniformFloat(shaderProgram, "material.roughness", 0.45f);
    setUniformFloat(shaderProgram, "material.ao", 1.0f);
}

void Lighting::bindShadowMap(GLuint shaderProgram, GLuint depthMapTexture, GLuint textureUnit) const
{
    glUseProgram(shaderProgram);
    glActiveTexture(GL_TEXTURE0 + textureUnit);
    glBindTexture(GL_TEXTURE_2D, depthMapTexture);
    setUniformInt(shaderProgram, "shadowMap", textureUnit);
}