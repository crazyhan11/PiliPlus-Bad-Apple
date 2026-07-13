/**
 * \file Vector.h
 * \brief
 *
 * vec2/vec3/vec4
 *
 * \version 1.0.0
 * \date 03/04/2023
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include "lmath/Math.h"

// clang-format off
#if defined(LMATH_USE_SSE4)
#	include <xmmintrin.h>
#	include <smmintrin.h>
#endif // LMATH_USE_SSE4
// clang-format on

namespace ldr {

class vec2i;
class vec2;
class vec3;
class vec4;

inline vec2i operator*(int a, const vec2i& b);
inline vec2 operator*(float a, const vec2& b);
inline vec3 operator*(float a, const vec3& b);
inline vec4 operator*(float a, const vec4& b);

class vec2 {
 public:
  float x;
  float y;

 public:
  vec2() {} // do not default-initialize
  vec2(float x, float y) : x(x), y(y) {}
  vec2(float x, int y) : x(x), y(static_cast<float>(y)) {}
  vec2(int x, float y) : x(static_cast<float>(x)), y(y) {}
  vec2(int x, int y) : x(static_cast<float>(x)), y(static_cast<float>(y)) {}
  vec2(unsigned int x, unsigned int y) : x(static_cast<float>(x)), y(static_cast<float>(y)) {}
  explicit vec2(const float a) : x(a), y(a) {}

  LFORCEINLINE float operator[](size_t idx) const {
    return (&x)[idx];
  };
  LFORCEINLINE float& operator[](size_t idx) {
    return (&x)[idx];
  };
  LFORCEINLINE vec2 operator-() const {
    return vec2(-x, -y);
  }

  LFORCEINLINE vec2 operator-(const vec2& v) const {
    return vec2(x - v.x, y - v.y);
  }
  LFORCEINLINE vec2 operator+(const vec2& v) const {
    return vec2(x + v.x, y + v.y);
  }
  LFORCEINLINE vec2 operator*(const vec2& v) const {
    return vec2(x * v.x, y * v.y);
  }
  LFORCEINLINE vec2 operator/(const vec2& v) const {
    return vec2(x / v.x, y / v.y);
  }

  LFORCEINLINE vec2 operator*(float a) const {
    return vec2(x * a, y * a);
  }
  LFORCEINLINE vec2 operator/(float a) const {
    return vec2(x / a, y / a);
  }

  LFORCEINLINE vec2& operator+=(const vec2& v) {
    x += v.x;
    y += v.y;
    return *this;
  }

  LFORCEINLINE vec2& operator-=(const vec2& v) {
    x -= v.x;
    y -= v.y;
    return *this;
  }

  LFORCEINLINE vec2& operator/=(float a) {
    x /= a;
    y /= a;
    return *this;
  }

  LFORCEINLINE vec2& operator/=(const vec2& v) {
    x /= v.x;
    y /= v.y;
    return *this;
  }

  LFORCEINLINE vec2& operator*=(float a) {
    x *= a;
    y *= a;
    return *this;
  }

  LFORCEINLINE vec2& operator*=(const vec2& v) {
    x *= v.x;
    y *= v.y;
    return *this;
  }

  LFORCEINLINE bool operator==(const vec2& v) const {
    return (v.x == x) && (v.y == y);
  }
  LFORCEINLINE bool operator!=(const vec2& v) const {
    return (v.x != x) || (v.y != y);
  }

  LFORCEINLINE const float* toFloatPtr() const {
    return &x;
  };
  LFORCEINLINE float* toFloatPtr() {
    return &x;
  };

  LFORCEINLINE float length() const {
    return sqrtf(x * x + y * y);
  };
  LFORCEINLINE float sqrLength() const {
    return x * x + y * y;
  };
  LFORCEINLINE float sum() const {
    return x + y;
  }
  LFORCEINLINE float avg() const {
    return (x + y) / 2.0f;
  }
  LFORCEINLINE float stdDev() const {
    const float m = avg();
    const float d1 = m - x;
    const float d2 = m - y;
    return sqrtf((d1 * d1 + d2 * d2) / 2.0f);
  }

  LFORCEINLINE void normalize() {
    *this /= length();
  }

  LFORCEINLINE vec2 getNormalized() const {
    vec2 v(*this);
    v.normalize();
    return v;
  };

  LFORCEINLINE float dot(const vec2& v) const {
    return x * v.x + y * v.y;
  }

  LFORCEINLINE vec2 getMinVector(const vec2& v) const {
    return vec2(x < v.x ? x : v.x, y < v.y ? y : v.y);
  }
  LFORCEINLINE vec2 getMaxVector(const vec2& v) const {
    return vec2(x > v.x ? x : v.x, y > v.y ? y : v.y);
  }
  LFORCEINLINE vec2 getOrthogonalVector() const {
    return vec2(-y, x);
  }

  LFORCEINLINE bool isZeroVector(float eps) const {
    return std::fabs(x) <= eps && std::fabs(y) <= eps;
  }

  LFORCEINLINE vec2& saturate() {
    x = ldr::clamp(x, 0.0f, 1.0f);
    y = ldr::clamp(y, 0.0f, 1.0f);
    return *this;
  }

  LFORCEINLINE vec2& abs() {
    x = std::abs(x);
    y = std::abs(y);
    return *this;
  }

  /// swizzles
  LFORCEINLINE vec2 yx() const {
    return vec2(y, x);
  };
};

class vec2i {
 public:
  int x;
  int y;

 public:
  vec2i() {} // do not default-initialize
  vec2i(int x, int y) : x(x), y(y) {}
  explicit vec2i(int a) : x(a), y(a) {}
  explicit vec2i(const vec2& v) : x(static_cast<int>(v.x)), y(static_cast<int>(v.y)) {}

  LFORCEINLINE int operator[](size_t idx) const {
    return (&x)[idx];
  };
  LFORCEINLINE int& operator[](size_t idx) {
    return (&x)[idx];
  };

  LFORCEINLINE vec2i operator-(const vec2i& v) const {
    return vec2i(x - v.x, y - v.y);
  }
  LFORCEINLINE vec2i operator+(const vec2i& v) const {
    return vec2i(x + v.x, y + v.y);
  }

  LFORCEINLINE bool operator==(const vec2i& v) const {
    return (v.x == x) && (v.y == y);
  }
  LFORCEINLINE bool operator!=(const vec2i& v) const {
    return (v.x != x) || (v.y != y);
  }

  LFORCEINLINE vec2i operator*(int a) const {
    return vec2i(x * a, y * a);
  }
  LFORCEINLINE vec2i operator/(int a) const {
    return vec2i(x / a, y / a);
  }

  LFORCEINLINE const int* toIntPtr() const {
    return &x;
  };
  LFORCEINLINE int* toIntPtr() {
    return &x;
  };

  LFORCEINLINE float length() const {
    return sqrtf(static_cast<float>(x * x + y * y));
  };
  LFORCEINLINE int sqrLength() const {
    return x * x + y * y;
  };
  LFORCEINLINE int sum() const {
    return x + y;
  }
  LFORCEINLINE float avg() const {
    return float(x + y) / 2.0f;
  }
};

class vec3 {
 public:
  float x;
  float y;
  float z;

 public:
  vec3() {} // do not default-initialize
  vec3(float x, float y) : x(x), y(y), z(0) {}
  vec3(float x, float y, float z) : x(x), y(y), z(z) {}
  vec3(int x, int y, int z) : x(static_cast<float>(x)), y(static_cast<float>(y)), z(static_cast<float>(z)) {}
  vec3(const vec2& v, float z) : x(v.x), y(v.y), z(z) {}
  explicit vec3(const float* f3) : x(f3[0]), y(f3[1]), z(f3[2]) {}
  explicit vec3(const vec2& v) : x(v.x), y(v.y), z(0) {}
  explicit vec3(int a) : x(static_cast<float>(a)), y(static_cast<float>(a)), z(static_cast<float>(a)) {}
  explicit vec3(float a) : x(a), y(a), z(a) {}

  LFORCEINLINE float operator[](size_t idx) const {
    return (&x)[idx];
  }
  LFORCEINLINE float& operator[](size_t idx) {
    return (&x)[idx];
  }

  LFORCEINLINE vec3 operator-() const {
    return vec3(-x, -y, -z);
  }
  LFORCEINLINE vec3 operator+() const {
    return vec3(+x, +y, +z);
  }

  LFORCEINLINE vec3 operator*(const float a) const {
    return vec3(x * a, y * a, z * a);
  }
  LFORCEINLINE vec3 operator/(const float a) const {
    return vec3(x / a, y / a, z / a);
  }

  LFORCEINLINE vec3 operator/(const vec3& v) const {
    return vec3(x / v.x, y / v.y, z / v.z);
  }

  LFORCEINLINE vec3 operator-(const vec3& v) const {
    return vec3(x - v.x, y - v.y, z - v.z);
  }
  LFORCEINLINE vec3 operator+(const vec3& v) const {
    return vec3(x + v.x, y + v.y, z + v.z);
  }

  LFORCEINLINE vec3& operator*=(float a) {
    x *= a;
    y *= a;
    z *= a;
    return *this;
  }

  LFORCEINLINE vec3& operator/=(float a) {
    x /= a;
    y /= a;
    z /= a;
    return *this;
  }

  LFORCEINLINE vec3& operator+=(const vec3& v) {
    x += v.x;
    y += v.y;
    z += v.z;
    return *this;
  }

  LFORCEINLINE vec3& operator-=(const vec3& v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;
    return *this;
  }

  LFORCEINLINE bool operator==(const vec3& v) const {
    return (v.x == x) && (v.y == y) && (v.z == z);
  }
  LFORCEINLINE bool operator!=(const vec3& v) const {
    return (v.x != x) || (v.y != y) || (v.z != z);
  }

  LFORCEINLINE vec3 operator*(const vec3& v) const {
    return vec3(x * v.x, y * v.y, z * v.z);
  }

  LFORCEINLINE const float* toFloatPtr() const {
    return &x;
  }
  LFORCEINLINE float* toFloatPtr() {
    return &x;
  }
  LFORCEINLINE vec2 toVector2() const {
    return vec2(x, y);
  }

  LFORCEINLINE bool isZeroVector(float eps) const {
#if defined(LMATH_USE_SSE4)
    const __m128 vec = _mm_setr_ps(x, y, z, 0.0f);
    const __m128 abs = _mm_max_ps(_mm_sub_ps(_mm_setzero_ps(), vec), vec);
    const __m128i cmp = _mm_castps_si128(_mm_cmpge_ps(abs, _mm_set1_ps(eps)));
    return _mm_testz_si128(cmp, cmp) != 0;
#else
    return std::fabs(x) <= eps && std::fabs(y) <= eps && std::fabs(z) <= eps;
#endif // LMATH_USE_SSE4
  }

  LFORCEINLINE vec3& saturate() {
    x = ldr::clamp(x, 0.0f, 1.0f);
    y = ldr::clamp(y, 0.0f, 1.0f);
    z = ldr::clamp(z, 0.0f, 1.0f);
    return *this;
  }

  LFORCEINLINE vec3& abs() {
#if defined(LMATH_USE_SSE4)
    const __m128 signBits = _mm_castsi128_ps(_mm_set1_epi32(0x80000000));
    const __m128 vec = _mm_andnot_ps(signBits, _mm_setr_ps(x, y, z, 0.0f));

    *this = vec3((float*)&vec);
#else
    x = std::fabs(x);
    y = std::fabs(y);
    z = std::fabs(z);
#endif // LMATH_USE_SSE4
    return *this;
  }

  LFORCEINLINE float length() const {
#if defined(LMATH_USE_SSE4)
    const __m128 vec = _mm_setr_ps(x, y, z, 0.0f);
    return _mm_cvtss_f32(_mm_sqrt_ss(_mm_dp_ps(vec, vec, 0x71)));
#else
    return sqrtf(x * x + y * y + z * z);
#endif // LMATH_USE_SSE4
  }
  LFORCEINLINE float sqrLength() const {
#if defined(LMATH_USE_SSE4)
    const __m128 vec = _mm_setr_ps(x, y, z, 0.0f);
    return _mm_cvtss_f32(_mm_dp_ps(vec, vec, 0x71));
#else
    return x * x + y * y + z * z;
#endif // LMATH_USE_SSE4
  }
  LFORCEINLINE float sum() const {
    return x + y + z;
  }
  LFORCEINLINE float avg() const {
    return (x + y + z) / 3.0f;
  }
  LFORCEINLINE float stdDev() const {
    const float m = avg();
    const float d1 = m - x;
    const float d2 = m - y;
    const float d3 = m - z;
    return sqrtf((d1 * d1 + d2 * d2 + d3 * d3) / 3.0f);
  }

  LFORCEINLINE void normalize() {
#if defined(LMATH_USE_SSE4)
    __m128 vec = _mm_setr_ps(x, y, z, 0.0f);
    vec = _mm_div_ps(vec, _mm_sqrt_ps(_mm_dp_ps(vec, vec, 0x7F)));

    *this = vec3((float*)&vec);
#else
    *this /= length();
#endif // LMATH_USE_SSE4
  }

  LFORCEINLINE vec3 getNormalized() const {
#if defined(LMATH_USE_SSE4)
    __m128 vec = _mm_setr_ps(x, y, z, 0.0f);
    vec = _mm_div_ps(vec, _mm_sqrt_ps(_mm_dp_ps(vec, vec, 0x7F)));
    return *(vec3*)&vec;
#else
    vec3 v(*this);
    v.normalize();
    return v;
#endif // LMATH_USE_SSE4
  };

  LFORCEINLINE float dot(const vec3& v) const {
    return x * v.x + y * v.y + z * v.z;
  }
  LFORCEINLINE vec3 cross(const vec3& v) const {
    return vec3(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x);
  }

  LFORCEINLINE size_t getMaximumComponentIndex() const {
    return x > y ? (x > z ? 0 : 2) : (y > z ? 1 : 2);
  }
  LFORCEINLINE size_t getMinimumComponentIndex() const {
    return x < y ? (x < z ? 0 : 2) : (y < z ? 1 : 2);
  }
  LFORCEINLINE size_t getMaximumComponentAbsIndex() const {
    using std::fabs;
    return fabs(x) > fabs(y) ? (fabs(x) > fabs(z) ? 0 : 2) : (fabs(y) > fabs(z) ? 1 : 2);
  }
  LFORCEINLINE size_t getMinimumComponentAbsIndex() const {
    using std::fabs;
    return fabs(x) < fabs(y) ? (fabs(x) < fabs(z) ? 0 : 2) : (fabs(y) < fabs(z) ? 1 : 2);
  }

  LFORCEINLINE float getMaximumComponent() const {
    return x > y ? (x > z ? x : z) : (y > z ? y : z);
  }
  LFORCEINLINE float getMinimumComponent() const {
    return x < y ? (x < z ? x : z) : (y < z ? y : z);
  }
  LFORCEINLINE float getMaximumComponentAbs() const {
    using std::fabs;
    return fabs(x) > fabs(y) ? (fabs(x) > fabs(z) ? fabs(x) : fabs(z)) : (fabs(y) > fabs(z) ? fabs(y) : fabs(z));
  }
  LFORCEINLINE float getMinimumComponentAbs() const {
    using std::fabs;
    return fabs(x) < fabs(y) ? (fabs(x) < fabs(z) ? fabs(x) : fabs(z)) : (fabs(y) < fabs(z) ? fabs(y) : fabs(z));
  }

  LFORCEINLINE vec3 getMinVector(const vec3& v) const {
#if defined(LMATH_USE_SSE4)
    const __m128 v1 = _mm_setr_ps(x, y, z, 0.0f);
    const __m128 v2 = _mm_setr_ps(v.x, v.y, v.z, 0.0f);
    const __m128 vec = _mm_min_ps(v1, v2);
    return *(vec3*)&vec;
#else
    return vec3(x < v.x ? x : v.x, y < v.y ? y : v.y, z < v.z ? z : v.z);
#endif // LMATH_USE_SSE4
  }

  LFORCEINLINE vec3 getMaxVector(const vec3& v) const {
#if defined(LMATH_USE_SSE4)
    const __m128 v1 = _mm_setr_ps(x, y, z, 0.0f);
    const __m128 v2 = _mm_setr_ps(v.x, v.y, v.z, 0.0f);
    const __m128 vec = _mm_max_ps(v1, v2);
    return *(vec3*)&vec;
#else
    return vec3(x > v.x ? x : v.x, y > v.y ? y : v.y, z > v.z ? z : v.z);
#endif // LMATH_USE_SSE4
  }

  vec3 getOrthogonalVector() const {
    if (getMaximumComponentAbs() < LMATH_EPSILON) {
      return vec3(1.0f, 0.0f, 1.0f);
    }

    switch (getMaximumComponentAbsIndex()) {
    case 0:
      return vec3(-(z + y) / x, 1.0f, 1.0f);
    case 1:
      return vec3(1.0f, -(z + x) / y, 1.0f);
    default:
      return vec3(1.0f, 1.0f, -(x + y) / z);
    }
  }

  /// swizzles
  LFORCEINLINE vec3 xzy() const {
    return vec3(x, z, y);
  }
  LFORCEINLINE vec3 yzx() const {
    return vec3(y, z, x);
  }
  LFORCEINLINE vec2 xz() const {
    return vec2(x, z);
  }
};

class vec3i {
 public:
  int x;
  int y;
  int z;

 public:
  vec3i() {} // do not default-initialize
  vec3i(int x, int y, int z) : x(x), y(y), z(z) {}
  explicit vec3i(int a) : x(a), y(a), z(a) {}

  LFORCEINLINE int operator[](size_t idx) const {
    return (&x)[idx];
  }
  LFORCEINLINE int& operator[](size_t idx) {
    return (&x)[idx];
  }

  LFORCEINLINE vec3i operator-(const vec3i& v) const {
    return vec3i(x - v.x, y - v.y, z - v.z);
  }
  LFORCEINLINE vec3i operator+(const vec3i& v) const {
    return vec3i(x + v.x, y + v.y, z + v.z);
  }

  LFORCEINLINE bool operator==(const vec3i& v) const {
    return (v.x == x) && (v.y == y) && (v.z == z);
  }
  LFORCEINLINE bool operator!=(const vec3i& v) const {
    return (v.x != x) || (v.y != y) || (v.z != z);
  }

  LFORCEINLINE vec3i operator*(int a) const {
    return vec3i(x * a, y * a, z * a);
  }
  LFORCEINLINE vec3i operator/(int a) const {
    return vec3i(x / a, y / a, z / a);
  }

  LFORCEINLINE vec3i getMinVector(const vec3i& v) const {
    return vec3i(x < v.x ? x : v.x, y < v.y ? y : v.y, z < v.z ? z : v.z);
  }
  LFORCEINLINE vec3i getMaxVector(const vec3i& v) const {
    return vec3i(x > v.x ? x : v.x, y > v.y ? y : v.y, z > v.z ? z : v.z);
  }

  LFORCEINLINE const int* toIntPtr() const {
    return &x;
  }
  LFORCEINLINE int* toIntPtr() {
    return &x;
  }

  LFORCEINLINE float length() const {
    return toVector3().length();
  }
  LFORCEINLINE int sqrLength() const {
    return x * x + y * y + z * z;
  }
  LFORCEINLINE int sum() const {
    return x + y + z;
  }
  LFORCEINLINE float avg() const {
    return float(x + y + z) / 3.0f;
  }

  LFORCEINLINE vec3 toVector3() const {
    return vec3(x, y, z);
  }
};

class vec4i {
 public:
  int x;
  int y;
  int z;
  int w;

 public:
  vec4i() {} // do not default-initialize
  vec4i(int x, int y, int z, int w) : x(x), y(y), z(z), w(w) {}
  vec4i(float x, float y, float z, float w)
  : x(static_cast<int>(x))
  , y(static_cast<int>(y))
  , z(static_cast<int>(z))
  , w(static_cast<int>(w)) {}
  explicit vec4i(int a) : x(a), y(a), z(a), w(a) {}

  LFORCEINLINE int operator[](size_t idx) const {
    return (&x)[idx];
  }
  LFORCEINLINE int& operator[](size_t idx) {
    return (&x)[idx];
  }

  LFORCEINLINE vec4i operator-(const vec4i& v) const {
    return vec4i(x - v.x, y - v.y, z - v.z, w - v.w);
  }
  LFORCEINLINE vec4i operator+(const vec4i& v) const {
    return vec4i(x + v.x, y + v.y, z + v.z, w + v.w);
  }

  LFORCEINLINE vec4i& operator-=(const vec4i& v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;
    w -= v.w;
    return *this;
  }

  LFORCEINLINE vec4i& operator+=(const vec4i& v) {
    x += v.x;
    y += v.y;
    z += v.z;
    w += v.w;
    return *this;
  }

  LFORCEINLINE bool operator==(const vec4i& v) const {
    return (v.x == x) && (v.y == y) && (v.z == z) && (v.w == w);
  }
  LFORCEINLINE bool operator!=(const vec4i& v) const {
    return (v.x != x) || (v.y != y) || (v.z != z) || (v.w != w);
  }

  LFORCEINLINE int dot(const vec4i& v) const {
    return (x * v.x + y * v.y + z * v.z + w * v.w);
  }

  vec4i& abs() {
    x = std::abs(x);
    y = std::abs(y);
    z = std::abs(z);
    w = std::abs(w);
    return *this;
  }

  /// swizzles
  LFORCEINLINE vec2i xy() const {
    return vec2i(x, y);
  }
  LFORCEINLINE vec2i yx() const {
    return vec2i(y, x);
  }
  LFORCEINLINE vec3i xyz() const {
    return vec3i(x, y, z);
  }
  LFORCEINLINE vec3i zyx() const {
    return vec3i(z, y, x);
  }
};

class vec4 {
 public:
  float x;
  float y;
  float z;
  float w;

 public:
  vec4() {} // do not default-initialize
  vec4(float x, float y) : x(x), y(y), z(0), w(0) {}
  vec4(float x, float y, float z, float w) : x(x), y(y), z(z), w(w) {}
  vec4(int x, int y, int z, int w)
  : x(static_cast<float>(x))
  , y(static_cast<float>(y))
  , z(static_cast<float>(z))
  , w(static_cast<float>(w)) {}
  vec4(const vec2& v, float z, float w) : x(v.x), y(v.y), z(z), w(w) {}
  vec4(const vec3& v, float w) : x(v.x), y(v.y), z(v.z), w(w) {}
  explicit vec4(const float* f4) : x(f4[0]), y(f4[1]), z(f4[2]), w(f4[3]) {}
  explicit vec4(int a) : x(static_cast<float>(a)), y(static_cast<float>(a)), z(static_cast<float>(a)), w(static_cast<float>(a)) {}
  explicit vec4(float a) : x(a), y(a), z(a), w(a) {}
  explicit vec4(const vec2& v) : x(v.x), y(v.y), z(0), w(0) {}
  explicit vec4(const vec3& v) : x(v.x), y(v.y), z(v.z), w(0) {}
  explicit vec4(const vec4i& v)
  : x(static_cast<float>(v.x))
  , y(static_cast<float>(v.y))
  , z(static_cast<float>(v.z))
  , w(static_cast<float>(v.w)) {}

  LFORCEINLINE float operator[](size_t idx) const {
    return (&x)[idx];
  }
  LFORCEINLINE float& operator[](size_t idx) {
    return (&x)[idx];
  }

  LFORCEINLINE vec4 operator-(const vec4& v) const {
    return vec4(x - v.x, y - v.y, z - v.z, w - v.w);
  }
  LFORCEINLINE vec4 operator+(const vec4& v) const {
    return vec4(x + v.x, y + v.y, z + v.z, w + v.w);
  }

  LFORCEINLINE vec4 operator*(float a) const {
    return vec4(x * a, y * a, z * a, w * a);
  }
  LFORCEINLINE vec4 operator/(float a) const {
    return vec4(x / a, y / a, z / a, w / a);
  }

  LFORCEINLINE vec4& operator*=(float a) {
    x *= a;
    y *= a;
    z *= a;
    w *= a;
    return *this;
  }

  LFORCEINLINE vec4& operator/=(float a) {
    x /= a;
    y /= a;
    z /= a;
    w /= a;
    return *this;
  }

  LFORCEINLINE vec4& operator-=(const vec4& v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;
    w -= v.w;
    return *this;
  }

  LFORCEINLINE vec4& operator+=(const vec4& v) {
    x += v.x;
    y += v.y;
    z += v.z;
    w += v.w;
    return *this;
  }

  LFORCEINLINE bool operator==(const vec4& v) const {
    return (v.x == x) && (v.y == y) && (v.z == z) && (v.w == w);
  }
  LFORCEINLINE bool operator!=(const vec4& v) const {
    return (v.x != x) || (v.y != y) || (v.z != z) || (v.w != w);
  }

  LFORCEINLINE vec4 operator*(const vec4& v) const {
    return vec4(x * v.x, y * v.y, z * v.z, w * v.w);
  }

  LFORCEINLINE float dot(const vec4& v) const {
    return (x * v.x + y * v.y + z * v.z + w * v.w);
  }

  LFORCEINLINE const float* toFloatPtr() const {
    return &x;
  }
  LFORCEINLINE float* toFloatPtr() {
    return &x;
  }

  LFORCEINLINE vec2 toVector2() const {
    return vec2(x, y);
  }
  LFORCEINLINE vec3 toVector3() const {
    return vec3(x, y, z);
  }
  LFORCEINLINE vec4i toVector4i() const {
    return vec4i(x, y, z, w);
  }

  LFORCEINLINE float length() const {
#if defined(LMATH_USE_SSE4)
    const __m128 vec = _mm_setr_ps(x, y, z, w);
    return _mm_cvtss_f32(_mm_sqrt_ss(_mm_dp_ps(vec, vec, 0xFF)));
#else
    return sqrtf(x * x + y * y + z * z + w * w);
#endif
  }
  LFORCEINLINE float sqrLength() const {
#if defined(LMATH_USE_SSE4)
    const __m128 vec = _mm_setr_ps(x, y, z, w);
    return _mm_cvtss_f32(_mm_dp_ps(vec, vec, 0xFF));
#else
    return x * x + y * y + z * z + w * w;
#endif
  }
  LFORCEINLINE float sum() const {
    return x + y + z + w;
  }
  LFORCEINLINE float avg() const {
    return (x + y + z + w) / 4.0f;
  }
  LFORCEINLINE float stdDev() const {
    const float m = avg();
    const float d1 = m - x;
    const float d2 = m - y;
    const float d3 = m - z;
    const float d4 = m - w;
    return sqrtf((d1 * d1 + d2 * d2 + d3 * d3 + d4 * d4) / 4.0f);
  }

  LFORCEINLINE void normalize() {
#if defined(LMATH_USE_SSE4)
    __m128 vec = _mm_setr_ps(x, y, z, w);
    vec = _mm_div_ps(vec, _mm_sqrt_ps(_mm_dp_ps(vec, vec, 0xFF)));

    *this = vec4((float*)&vec);
#else
    *this /= length();
#endif
  }

  LFORCEINLINE vec4 getNormalized() const {
#if defined(LMATH_USE_SSE4)
    __m128 vec = _mm_setr_ps(x, y, z, w);
    vec = _mm_div_ps(vec, _mm_sqrt_ps(_mm_dp_ps(vec, vec, 0xFF)));
    return *(vec4*)&vec;
#else
    vec4 v(*this);
    v.normalize();
    return v;
#endif // LMATH_USE_SSE4
  }

  LFORCEINLINE bool isZeroVector(float eps) const {
#if defined(LMATH_USE_SSE4)
    const __m128 vec = _mm_loadu_ps(&x);
    const __m128 abs = _mm_max_ps(_mm_sub_ps(_mm_setzero_ps(), vec), vec);
    const __m128i cmp = _mm_castps_si128(_mm_cmpge_ps(abs, _mm_set1_ps(eps)));
    return _mm_testz_si128(cmp, cmp) != 0;
#else
    return std::fabs(x) <= eps && std::fabs(y) <= eps && std::fabs(z) <= eps && std::fabs(w) <= eps;
#endif // LMATH_USE_SSE4
  }

  LFORCEINLINE vec4& saturate() {
    x = ldr::clamp(x, 0.0f, 1.0f);
    y = ldr::clamp(y, 0.0f, 1.0f);
    z = ldr::clamp(z, 0.0f, 1.0f);
    w = ldr::clamp(w, 0.0f, 1.0f);
    return *this;
  }

  LFORCEINLINE vec4& abs() {
    x = std::fabs(x);
    y = std::fabs(y);
    z = std::fabs(z);
    w = std::fabs(w);
    return *this;
  }

  /// swizzles
  LFORCEINLINE vec4 bgra() const {
    return vec4(z, y, x, w);
  };
  LFORCEINLINE vec2 xy() const {
    return vec2(x, y);
  }
  LFORCEINLINE vec2 yx() const {
    return vec2(y, x);
  }
  LFORCEINLINE vec2 zw() const {
    return vec2(z, w);
  }
  LFORCEINLINE vec3 xyz() const {
    return vec3(x, y, z);
  }
  LFORCEINLINE vec3 xzy() const {
    return vec3(x, z, y);
  }
  LFORCEINLINE vec3 yxz() const {
    return vec3(y, x, z);
  }
  LFORCEINLINE vec3 yzx() const {
    return vec3(y, z, x);
  }
  LFORCEINLINE vec3 zyx() const {
    return vec3(z, y, x);
  }
  LFORCEINLINE vec3 zyz() const {
    return vec3(z, y, z);
  }
};

LFORCEINLINE vec2 operator*(float a, const vec2& b) {
  return vec2(b.x * a, b.y * a);
}

LFORCEINLINE vec2i operator*(int a, const vec2i& b) {
  return vec2i(b.x * a, b.y * a);
}

LFORCEINLINE vec3 operator*(float a, const vec3& b) {
  return vec3(b.x * a, b.y * a, b.z * a);
}

LFORCEINLINE vec4 operator*(float a, const vec4& b) {
  return vec4(b.x * a, b.y * a, b.z * a, b.w * a);
}

LFORCEINLINE vec2 normalize(const vec2 v) {
  return v / v.length();
}

LFORCEINLINE vec3 normalize(const vec3& v) {
  return v / v.length();
}

LFORCEINLINE vec4 normalize(const vec4& v) {
  return v / v.length();
}

LFORCEINLINE vec3 cross(const vec3& v1, const vec3& v2) {
  return v1.cross(v2);
}

LFORCEINLINE float dot(const vec2& v1, const vec2& v2) {
  return v1.dot(v2);
}

LFORCEINLINE float dot(const vec3& v1, const vec3& v2) {
  return v1.dot(v2);
}

inline vec2 lerp(const vec2& v1, const vec2& v2, float t) {
  if (t <= 0.0f) {
    return v1;
  } else if (t >= 1.0f) {
    return v2;
  } else {
    return v1 + t * (v2 - v1);
  }
}

inline vec3 lerp(const vec3& v1, const vec3& v2, float t) {
  if (t <= 0.0f) {
    return v1;
  } else if (t >= 1.0f) {
    return v2;
  } else {
    return v1 + t * (v2 - v1);
  }
}

inline vec4 lerp(const vec4& v1, const vec4& v2, float t) {
  if (t <= 0.0f) {
    return v1;
  } else if (t >= 1.0f) {
    return v2;
  } else {
    return v1 + t * (v2 - v1);
  }
}

LFORCEINLINE vec4 clamp(const vec4& v, const vec4& minVal, const vec4& maxVal) {
  return vec4(
      clamp(v.x, minVal.x, maxVal.x), clamp(v.y, minVal.y, maxVal.y), clamp(v.z, minVal.z, maxVal.z), clamp(v.w, minVal.w, maxVal.w));
}

// 32-bit RGBA colors, etc
class vec4b {
 public:
  uint8_t x;
  uint8_t y;
  uint8_t z;
  uint8_t w;

 public:
  vec4b() {} // do not default-initialize
  vec4b(uint8_t x, uint8_t y, uint8_t z, uint8_t w) : x(x), y(y), z(z), w(w) {}
  explicit vec4b(const uint8_t a) : x(a), y(a), z(a), w(a) {}
  explicit vec4b(const vec4& v)
  : x(static_cast<uint8_t>(v.x * 255.0f))
  , y(static_cast<uint8_t>(v.y * 255.0f))
  , z(static_cast<uint8_t>(v.z * 255.0f))
  , w(static_cast<uint8_t>(v.w * 255.0f)) {}
};

} // namespace ldr

#if defined(LMATH_USE_SHORTCUT_TYPES)
using vec2 = ldr::vec2;
using vec3 = ldr::vec3;
using vec4 = ldr::vec4;
using vec2i = ldr::vec2i;
using vec3i = ldr::vec3i;
using vec4i = ldr::vec4i;
using vec4b = ldr::vec4b;
#endif // LMATH_USE_SHORTCUT_TYPES
