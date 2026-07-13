/**
 * \file GeometryShapes.h
 * \brief
 *
 * Basic geometry shapes
 *
 * \author Sergey Kosarevsky, 2025
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <memory>
#include <vector>

#if (!defined(GS_VEC2) || !defined(GS_VEC3)) && __has_include(<glm/glm.hpp>)
#include <glm/glm.hpp>
using GS_VEC2 = glm::vec2;
using GS_VEC3 = glm::vec3;
#else
#include <lmath/Vector.h>
using GS_VEC2 = ldr::vec2;
using GS_VEC3 = ldr::vec3;
#endif

namespace GeometryShapes {

struct Vertex final {
  GS_VEC3 pos = {0, 0, 0};
  GS_VEC2 uv = {0, 0};
  GS_VEC3 normal = {0, 0, 1};
};

std::vector<Vertex> createQuad2D(GS_VEC2 a, GS_VEC2 b, const float z = 0.0f); // TRIANGLE_STRIP

std::vector<Vertex> createIcosahedron(GS_VEC3 center, float r); // TRIANGLE

std::vector<Vertex> createDisk(float innerRadius, float outerRadius, int numSlices = 40); // TRIANGLE_STRIP

std::vector<Vertex> createOrbit(float radius, int subdivision); // LINE_STRIP

std::vector<Vertex> createAxisAlignedBox(GS_VEC3 center, GS_VEC3 halfDiagonal); // TRIANGLE

// subdivision level: 0 - icosahedron
std::vector<Vertex> createIcoSphere(GS_VEC3 center, float radius, unsigned int subdivision); // TRIANGLE

void addAxisAlignedBox(std::vector<Vertex>& v, GS_VEC3 center, GS_VEC3 halfDiagonal);

} // namespace GeometryShapes
