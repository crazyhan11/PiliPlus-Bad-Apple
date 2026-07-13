/**
 * \file Random.h
 * \brief
 *
 * A very fast PRNG without extra dependencies (based on https://iquilezles.org/articles/sfrand/)
 *
 * \author Sergey Kosarevsky, 2026
 * \author sk@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <cmath>
#include <cstdint>
#include <cstring>

#if (!defined(RND_VEC2) || !defined(RND_VEC3) || !defined(RND_VEC4)) && __has_include(<glm/glm.hpp>)
#include <glm/glm.hpp>
using RND_VEC2 = glm::vec2;
using RND_VEC3 = glm::vec3;
using RND_VEC4 = glm::vec4;
#else
#include <lmath/Vector.h>
using RND_VEC2 = ldr::vec2;
using RND_VEC3 = ldr::vec3;
using RND_VEC4 = ldr::vec4;
#endif

/// a very fast PRNG without extra dependencies
struct LRandom {
  uint32_t seed_ = 7;

  // based on https://iquilezles.org/articles/sfrand/
  float random() {
    seed_ *= 16807;
    const uint32_t a = (seed_ & 0x007fffff) | 0x40000000;
    // remap to 0..1
    float f;
    memcpy(&f, &a, sizeof(f));
    return 0.5f * (f - 2.0f);
  }

  float randomInRange(float rMin, float rMax) {
    return rMin + random() * (rMax - rMin);
  }
  RND_VEC2 randomVector2InRange(const RND_VEC2& rMin, const RND_VEC2& rMax) {
    return RND_VEC2(randomInRange(rMin.x, rMax.x), randomInRange(rMin.y, rMax.y));
  }
  RND_VEC3 randomVector3InRange(const RND_VEC3& rMin, const RND_VEC3& rMax) {
    return RND_VEC3(randomInRange(rMin.x, rMax.x), randomInRange(rMin.y, rMax.y), randomInRange(rMin.z, rMax.z));
  }
  RND_VEC4 randomVector4InRange(const RND_VEC4& rMin, const RND_VEC4& rMax) {
    return RND_VEC4(
        randomInRange(rMin.x, rMax.x), randomInRange(rMin.y, rMax.y), randomInRange(rMin.z, rMax.z), randomInRange(rMin.w, rMax.w));
  }
  // Marsaglia (1972) method: http://mathworld.wolfram.com/SpherePointPicking.html
  RND_VEC3 randomVector3OnUnitSphereSurface() {
    float u, v, s;
    do {
      u = randomInRange(-1.0f, +1.0f);
      v = randomInRange(-1.0f, +1.0f);
      s = u * u + v * v;
    } while (s >= 1.0f || s == 0.0f);
    const float t = 2.0f * sqrtf(1.0f - s);
    return RND_VEC3(u * t, v * t, 1.0f - 2.0f * s);
  }
  RND_VEC3 randomVector3InsideUnitSphere() {
    float x, y, z;
    float d = 1.0f;
    while (d >= 1.0f) {
      x = randomInRange(-1.0f, +1.0f);
      y = randomInRange(-1.0f, +1.0f);
      z = randomInRange(-1.0f, +1.0f);
      d = x * x + y * y + z * z;
    }
    return RND_VEC3(x, y, z);
  }
};
