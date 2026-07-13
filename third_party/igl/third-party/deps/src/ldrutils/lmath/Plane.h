/**
 * \file Plane.h
 * \brief
 *
 * 3d plane
 *
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <lmath/Matrix.h>
#include <lmath/Vector.h>

namespace ldr {

enum ePlaneClassify {
  ePlaneClassify_Front = 0,
  ePlaneClassify_Back = 1,
  ePlaneClassify_Plane = 2,
};

class plane3 {
 public:
  vec3 n;
  float d;

 public:
  plane3() : n(0.0f, 0.0f, 1.0f), d(0.0f) {}
  /// from a plane equation
  explicit plane3(const vec4& v) : n(v.toVector3()), d(v.w) {}
  /// from a normal and parameter
  explicit plane3(const vec3& normal, float d) : n(normal), d(d) {}
  /// from a plane equation
  plane3(float nx, float ny, float nz, float d) : n(vec3(nx, ny, nz)), d(d) {}
  /// from a point and normal
  plane3(const vec3& pt, const vec3& normal) : n(normal), d(-dot(pt, normal)) {}
  /// from 3 points
  plane3(const vec3& p1, const vec3& p2, const vec3& p3) : plane3(p1, ldr::normalize(cross(p2 - p1, p3 - p1))) {}
  LFORCEINLINE float operator[](size_t idx) const {
    return n[idx];
  };
  LFORCEINLINE float& operator[](size_t idx) {
    return n[idx];
  };
  LFORCEINLINE const float* toFloatPtr() const {
    return n.toFloatPtr();
  }
  LFORCEINLINE float* toFloatPtr() {
    return n.toFloatPtr();
  }
  LFORCEINLINE vec4 toVector4() const {
    return vec4(n, d);
  }
  LFORCEINLINE vec3 toVector3() const {
    return n;
  }
  LFORCEINLINE vec3 getNormal() const {
    return n;
  }

  LFORCEINLINE void invert() {
    n = -n;
  }
  LFORCEINLINE plane3 getInverted() const {
    return plane3(-n, d);
  }

  LFORCEINLINE void normalize() {
    const float len = n.length();
    n /= len;
    d /= len;
  }
  LFORCEINLINE plane3 getNormalized() const {
    plane3 v(*this);
    v.normalize();
    return v;
  }

  LFORCEINLINE float getDistanceToPointSigned(const vec3& pt) const {
    return n.dot(pt) + d;
  }
  LFORCEINLINE float getDistanceToPoint(const vec3& pt) const {
    return ldr::absf(getDistanceToPointSigned(pt));
  }

  /// intersection of N-ray with this plane
  LFORCEINLINE vec3 getPointOnPlane() const {
    return d * n / n.dot(n);
  }
  /// project vector's ends to plane's normal
  LFORCEINLINE vec3 projectToNormal(const vec3& v) const {
    return (v * n) * n;
  }
  /// project vector's ends to plane
  LFORCEINLINE vec3 projectPoint(const vec3& pt) const {
    return pt - projectToNormal(pt) + d * n;
  }

  LFORCEINLINE void buildBasis(vec3* v1, vec3* v2) const {
    *v1 = n.getOrthogonalVector();
    *v2 = ldr::normalize(cross(n, *v1));
  }

  /// construct a reflection matrix for this plane
  LFORCEINLINE mat4 reflect() const {
    // clang-format off
		return mat4(
			 vec4(-2.0f * n.x * n.x + 1.0f, -2.0f * n.y * n.x,        -2.0f * n.z * n.x,        0.0f),
			 vec4(-2.0f * n.x * n.y,        -2.0f * n.y * n.y + 1.0f, -2.0f * n.z * n.y,        0.0f),
			 vec4(-2.0f * n.x * n.z,        -2.0f * n.y * n.z,        -2.0f * n.z * n.z + 1.0f, 0.0f),
			 vec4(-2.0f * n.x * d,          -2.0f * n.y * d,          -2.0f * n.z * d,          1.0f));
    // clang-format on
  }

  /// Classify the location of point respectively to this plane (front, back, in-plane)
  ePlaneClassify classifyPoint(const vec3& pt) const {
    const float d = getDistanceToPointSigned(pt);

    if (d > LMATH_EPSILON) {
      return ePlaneClassify_Front;
    }
    if (d < -LMATH_EPSILON) {
      return ePlaneClassify_Back;
    }
    return ePlaneClassify_Plane;
  }

  /**
   * Compute which subspace N is pointing to:
   *       Nx Ny Nz
   *    0  +  +  +
   *    1  -  +  +
   *    2  +  -  +
   *    3  -  -  +
   *    4  +  +  -
   *    5  -  +  -
   *    6  +  -  -
   *    7  -  -  -
   **/
  LFORCEINLINE static int getNearPointMask(const vec3& n) {
    return n.x > 0 ? (n.y > 0 ? (n.z > 0 ? 0 : 4) : (n.z > 0 ? 2 : 6)) : (n.y > 0 ? (n.z > 0 ? 1 : 5) : (n.z > 0 ? 3 : 7));
  }
};

static_assert(sizeof(plane3) == sizeof(vec4));

} // namespace ldr

#if defined(LMATH_USE_SHORTCUT_TYPES)
using plane3 = ldr::plane3;
#endif // LMATH_USE_SHORTCUT_TYPES
