/**
 * \file Ray.h
 * \brief
 *
 * 3d ray
 *
 * \version 1.0.0
 * \date 16/04/2023
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <lmath/Vector.h>

namespace ldr {

class ray3 {
 public:
  vec3 orig;
  vec3 dir;

 public:
  ray3() = default;
  explicit ray3(const vec3& dir) : orig(0.0f), dir(dir) {}
  ray3(const vec3& orig, const vec3& dir) : orig(orig), dir(dir) {}
  LFORCEINLINE void normalize() {
    dir.normalize();
  }
  LFORCEINLINE vec3 getPoint(float t) const {
    return orig + t * dir;
  }
  /// return the parameter 't'
  LFORCEINLINE float projectPoint(const vec3& p) const {
    return dot(p - orig, dir);
  }
  /// return the projected point
  LFORCEINLINE vec3 projectPointVec3(const vec3& p) const {
    return orig + projectPoint(p) * dir;
  }
};

} // namespace ldr

#if defined(LMATH_USE_SHORTCUT_TYPES)
using ray3 = ldr::ray3;
#endif // LMATH_USE_SHORTCUT_TYPES
