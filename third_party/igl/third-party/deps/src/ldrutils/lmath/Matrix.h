/**
 * \file Matrix.h
 * \brief
 *
 * mat3/mat4
 *
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include "lmath/Vector.h"

// clang-format off
#if defined(LMATH_USE_AVX2)
#  include <immintrin.h>
#endif // LMATH_USE_AVX2
// clang-format on

namespace ldr {

class mat3 {
 public:
  vec3 m[3];

 public:
  mat3() {} // do not default-initialize
  LFORCEINLINE explicit mat3(float a) {
    m[0] = vec3(a, 0.0f, 0.0f);
    m[1] = vec3(0.0f, a, 0.0f);
    m[2] = vec3(0.0f, 0.0f, a);
  }
  LFORCEINLINE mat3(const vec3& x, const vec3& y, const vec3& z) {
    m[0] = x;
    m[1] = y;
    m[2] = z;
  }

  LFORCEINLINE vec3& operator[](size_t idx) {
    return m[idx];
  };
  LFORCEINLINE const vec3& operator[](size_t idx) const {
    return m[idx];
  };

  LFORCEINLINE mat3 operator+(const mat3& mat) const {
    mat3 r;

    for (size_t i = 0; i != 3; i++)
      for (size_t j = 0; j != 3; j++)
        r[i][j] = m[i][j] + mat[i][j];

    return r;
  }
  LFORCEINLINE vec3 operator*(const vec3& v) const {
    const float x = m[0].x * v.x + m[1].x * v.y + m[2].x * v.z;
    const float y = m[0].y * v.x + m[1].y * v.y + m[2].y * v.z;
    const float z = m[0].z * v.x + m[1].z * v.y + m[2].z * v.z;
    return vec3(x, y, z);
  }
  LFORCEINLINE mat3 operator*(const mat3& m) const;

  LFORCEINLINE const float* toFloatPtr() const {
    return m[0].toFloatPtr();
  };
  LFORCEINLINE float* toFloatPtr() {
    return m[0].toFloatPtr();
  };

  LFORCEINLINE void makeZero() {
    m[0] = vec3(0);
    m[1] = vec3(0);
    m[2] = vec3(0);
  }
  LFORCEINLINE void makeIdentity() {
    m[0] = vec3(1, 0, 0);
    m[1] = vec3(0, 1, 0);
    m[2] = vec3(0, 0, 1);
  }
  LFORCEINLINE static mat3 getIdentity() {
    return mat3(vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1));
  };

  void inverse();
  mat3 getInversed() const;

  void transpose();
  mat3 getTransposed() const;

  void orthonormalize();
  mat3 getOrthonormalized() const;

  static mat3 getRotateAngleAxis(float angleRad, const vec3& axisNormalized);
  static mat3 getRotate(const vec3& v1, const vec3& v2);

  inline bool isEqual(const mat3& other, float eps = LMATH_EPSILON) const {
    for (size_t i = 0; i != 3; ++i) {
      for (size_t j = 0; j != 3; ++j) {
        if (absf(m[i][j] - other[i][j]) > eps)
          return false;
      }
    }
    return true;
  }
};

mat3 mat3::operator*(const mat3& m) const {
  mat3 result;

  const float* m1 = toFloatPtr();
  const float* m2 = m.toFloatPtr();
  float* r = result.toFloatPtr();

  for (size_t i = 0; i != 3; ++i) {
    for (size_t j = 0; j != 3; ++j)
      *r++ = m1[0] * m2[0 * 3 + j] + m1[1] * m2[1 * 3 + j] + m1[2] * m2[2 * 3 + j];

    m1 += 3;
  }

  return result;
}

class mat4 {
 public:
  vec4 m[4];

 public:
  mat4() {} // do not default-initialize
  LFORCEINLINE explicit mat4(float a) {
    m[0] = vec4(a, 0.0f, 0.0f, 0.0f);
    m[1] = vec4(0.0f, a, 0.0f, 0.0f);
    m[2] = vec4(0.0f, 0.0f, a, 0.0f);
    m[3] = vec4(0.0f, 0.0f, 0.0f, a);
  }
  LFORCEINLINE mat4(const vec4& x, const vec4& y, const vec4& z, const vec4& w) {
    m[0] = x;
    m[1] = y;
    m[2] = z;
    m[3] = w;
  }
  // clang-format off
	LFORCEINLINE mat4(float a00, float a01, float a02, float a03,
	                  float a10, float a11, float a12, float a13,
	                  float a20, float a21, float a22, float a23,
	                  float a30, float a31, float a32, float a33)
  // clang-format on
  {
    m[0] = vec4(a00, a01, a02, a03);
    m[1] = vec4(a10, a11, a12, a13);
    m[2] = vec4(a20, a21, a22, a23);
    m[3] = vec4(a30, a31, a32, a33);
  };
  LFORCEINLINE explicit mat4(const mat3& s) {
    m[0] = vec4(s.m[0], 0.0f);
    m[1] = vec4(s.m[1], 0.0f);
    m[2] = vec4(s.m[2], 0.0f);
    m[3] = vec4(0.0f, 0.0f, 0.0f, 1.0f);
  }

  LFORCEINLINE vec4& operator[](size_t idx) {
    return m[idx];
  };
  LFORCEINLINE const vec4& operator[](size_t idx) const {
    return m[idx];
  };

  inline mat4 operator+(const mat4& mat) const;
  inline mat4 operator*(const mat4& mat) const;
  inline vec4 operator*(const vec4& v) const;
  inline vec3 operator*(const vec3& v) const;

  LFORCEINLINE const float* toFloatPtr() const {
    return m[0].toFloatPtr();
  };
  LFORCEINLINE float* toFloatPtr() {
    return m[0].toFloatPtr();
  };

  LFORCEINLINE void makeZero() {
#if defined(LMATH_USE_AVX2)
    float* a = this->toFloatPtr();
    const __m256 zero = _mm256_setzero_ps();
    _mm256_storeu_ps(a + 0, zero);
    _mm256_storeu_ps(a + 8, zero);
#elif defined(LMATH_USE_SSE4)
    float* a = this->toFloatPtr();
    const __m128 zero = _mm_setzero_ps();
    _mm_storeu_ps(a + 0, zero);
    _mm_storeu_ps(a + 4, zero);
    _mm_storeu_ps(a + 8, zero);
    _mm_storeu_ps(a + 12, zero);
#else
    for (size_t i = 0; i != 4; ++i) {
      m[i] = vec4(0);
    }
#endif // LMATH_USE_SSE4
  }
  LFORCEINLINE void makeIdentity() {
#if defined(LMATH_USE_AVX2)
    float* a = this->toFloatPtr();
    _mm256_storeu_ps(a + 0, _mm256_setr_ps(1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f));
    _mm256_storeu_ps(a + 8, _mm256_setr_ps(0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f));
#elif defined(LMATH_USE_SSE4)
    float* a = this->toFloatPtr();
    _mm_storeu_ps(a + 0, _mm_setr_ps(1.0f, 0.0f, 0.0f, 0.0f));
    _mm_storeu_ps(a + 4, _mm_setr_ps(0.0f, 1.0f, 0.0f, 0.0f));
    _mm_storeu_ps(a + 8, _mm_setr_ps(0.0f, 0.0f, 1.0f, 0.0f));
    _mm_storeu_ps(a + 12, _mm_setr_ps(0.0f, 0.0f, 0.0f, 1.0f));
#else
    m[0] = vec4(1.0f, 0.0f, 0.0f, 0.0f);
    m[1] = vec4(0.0f, 1.0f, 0.0f, 0.0f);
    m[2] = vec4(0.0f, 0.0f, 1.0f, 0.0f);
    m[3] = vec4(0.0f, 0.0f, 0.0f, 1.0f);
#endif // LMATH_USE_SSE4
  }
  LFORCEINLINE static mat4 getIdentity() {
    mat4 m;
    m.makeIdentity();
    return m;
  };
  inline bool isIdentity(float eps = LMATH_EPSILON) const {
    const mat4 identity = mat4::getIdentity();

    for (size_t i = 0; i != 4; ++i) {
      for (size_t j = 0; j != 4; ++j) {
        if (absf(m[i][j] - identity[i][j]) > eps)
          return false;
      }
    }
    return true;
  }

  static mat4 getRotateAngleAxis(float angleRad, const vec3& axisNormalized);
  static mat4 getRotate(const vec3& v1, const vec3& v2);
  static mat4 getTranslate(const vec3& v);
  static mat4 getScale(const vec3& v);
  static mat4 getFromPitchPanRoll(float degPitch, float degPan, float degRoll);

  inline bool isEqual(const mat4& other, float eps = LMATH_EPSILON) const {
    for (size_t i = 0; i != 4; ++i) {
      for (size_t j = 0; j != 4; ++j) {
        if (absf(m[i][j] - other[i][j]) > eps)
          return false;
      }
    }
    return true;
  }

  void inverse();
  mat4 getInversed() const;

  void transpose();
  mat4 getTransposed() const;

  float det() const;

  LFORCEINLINE mat3 toMat3() const {
    return mat3(m[0].toVector3(), m[1].toVector3(), m[2].toVector3());
  }
};

inline bool operator==(const mat4& m1, const mat4& m2) {
  const float* m1Ptr = m1.toFloatPtr();
  const float* m2Ptr = m2.toFloatPtr();

  for (size_t i = 0; i != 16; ++i) {
    if (m1Ptr[i] != m2Ptr[i])
      return false;
  }

  return true;
}

inline bool operator!=(const mat4& m1, const mat4& m2) {
  const float* m1Ptr = m1.toFloatPtr();
  const float* m2Ptr = m2.toFloatPtr();

  for (size_t i = 0; i != 16; ++i) {
    if (m1Ptr[i] != m2Ptr[i])
      return true;
  }

  return false;
}

inline mat4 mat4::operator+(const mat4& mat) const {
  mat4 r;

  for (size_t i = 0; i != 4; i++)
    for (size_t j = 0; j != 4; j++)
      r[i][j] = m[i][j] + mat[i][j];

  return r;
}

inline mat4 mat4::operator*(const mat4& mat) const {
  mat4 r;

  const float* LRESTRICT m1Ptr = this->toFloatPtr();
  const float* LRESTRICT m2Ptr = mat.toFloatPtr();
  float* LRESTRICT RPtr = r.toFloatPtr();

#if defined(LMATH_USE_SSE4)
  __m128 r1 = _mm_loadu_ps(m2Ptr + 0);
  __m128 r2 = _mm_loadu_ps(m2Ptr + 4);
  __m128 r3 = _mm_loadu_ps(m2Ptr + 8);
  __m128 r4 = _mm_loadu_ps(m2Ptr + 12);
  for (size_t i = 0; i < 16; i += 4) {
    __m128 b1 = _mm_set1_ps(m1Ptr[i + 0]);
    __m128 b2 = _mm_set1_ps(m1Ptr[i + 1]);
    __m128 b3 = _mm_set1_ps(m1Ptr[i + 2]);
    __m128 b4 = _mm_set1_ps(m1Ptr[i + 3]);
    // clang-format off
		_mm_storeu_ps(RPtr + i, _mm_add_ps(
			_mm_add_ps(_mm_mul_ps(b1, r1), _mm_mul_ps(b2, r2)),
			_mm_add_ps(_mm_mul_ps(b3, r3), _mm_mul_ps(b4, r4))));
    // clang-format on
  }
#else
  for (size_t i = 0; i != 4; i++) {
    for (size_t j = 0; j != 4; j++) {
      // clang-format off
			*RPtr++ = m1Ptr[0] * m2Ptr[0 + j] +
				       m1Ptr[1] * m2Ptr[4 + j] +
				       m1Ptr[2] * m2Ptr[8 + j] +
				       m1Ptr[3] * m2Ptr[12 + j];
      // clang-format on
    }
    m1Ptr += 4;
  }
#endif // LMATH_USE_SSE4

  return r;
}

inline vec4 mat4::operator*(const vec4& v) const {
  // clang-format off
	return vec4(
		m[0].x * v.x + m[1].x * v.y + m[2].x * v.z + m[3].x * v.w,
	   m[0].y * v.x + m[1].y * v.y + m[2].y * v.z + m[3].y * v.w,
	   m[0].z * v.x + m[1].z * v.y + m[2].z * v.z + m[3].z * v.w,
	   m[0].w * v.x + m[1].w * v.y + m[2].w * v.z + m[3].w * v.w);
  // clang-format on
}

inline vec3 mat4::operator*(const vec3& v) const {
  // clang-format off
	return vec3(
	   m[0].x * v.x + m[1].x * v.y + m[2].x * v.z + m[3].x,
	   m[0].y * v.x + m[1].y * v.y + m[2].y * v.z + m[3].y,
	   m[0].z * v.x + m[1].z * v.y + m[2].z * v.z + m[3].z
	);
  // clang-format on
}

class mat3x4 {
 public:
  vec3 m[4];

  LFORCEINLINE explicit mat3x4(const mat4& m) : m{m[0].toVector3(), m[1].toVector3(), m[2].toVector3(), m[3].toVector3()} {}
};

} // namespace ldr

#if defined(LMATH_USE_SHORTCUT_TYPES)
using mat3 = ldr::mat3;
using mat4 = ldr::mat4;
using mat3x4 = ldr::mat3x4;
#endif // LMATH_USE_SHORTCUT_TYPES
