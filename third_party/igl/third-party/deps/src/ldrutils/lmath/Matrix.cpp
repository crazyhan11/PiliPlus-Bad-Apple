/**
 * \file Matrix.cpp
 * \brief
 *
 * mat3/mat4
 *
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#include "lmath/Matrix.h"

namespace ldr
{

void mat3::inverse()
{
	mat3 inv;

	inv[0][0] = m[1][1] * m[2][2] - m[1][2] * m[2][1];
	inv[1][0] = m[1][2] * m[2][0] - m[1][0] * m[2][2];
	inv[2][0] = m[1][0] * m[2][1] - m[1][1] * m[2][0];

	const float det = m[0][0] * inv[0][0] + m[0][1] * inv[1][0] + m[0][2] * inv[2][0];

	if (fabsf(det) < LMATH_EPSILON)
		return;

	const float invDet = 1.0f / det;

	inv[0][1] = m[0][2] * m[2][1] - m[0][1] * m[2][2];
	inv[0][2] = m[0][1] * m[1][2] - m[0][2] * m[1][1];
	inv[1][1] = m[0][0] * m[2][2] - m[0][2] * m[2][0];
	inv[1][2] = m[0][2] * m[1][0] - m[0][0] * m[1][2];
	inv[2][1] = m[0][1] * m[2][0] - m[0][0] * m[2][1];
	inv[2][2] = m[0][0] * m[1][1] - m[0][1] * m[1][0];

	m[0][0] = inv[0][0] * invDet;
	m[0][1] = inv[0][1] * invDet;
	m[0][2] = inv[0][2] * invDet;

	m[1][0] = inv[1][0] * invDet;
	m[1][1] = inv[1][1] * invDet;
	m[1][2] = inv[1][2] * invDet;

	m[2][0] = inv[2][0] * invDet;
	m[2][1] = inv[2][1] * invDet;
	m[2][2] = inv[2][2] * invDet;
}

mat3 mat3::getInversed() const
{
	mat3 inv(*this);

	inv.inverse();

	return inv;
}

void mat3::transpose()
{
	for (size_t i = 0; i != 3; i++) {
		for (size_t j = 0; j != 3; j++) {
			const float tmp = m[i][j];
			m[i][j]         = m[j][i];
			m[j][i]         = tmp;
		}
	}
}

mat3 mat3::getTransposed() const
{
	mat3 t;

	for (size_t i = 0; i != 3; i++)
		for (size_t j = 0; j != 3; j++)
			t[i][j] = m[j][i];

	return t;
}

void mat3::orthonormalize()
{
	m[0].normalize();
	m[2] = m[0].cross(m[1]);
	m[2].normalize();
	m[1] = m[2].cross(m[0]);
	m[1].normalize();
}

mat3 mat3::getOrthonormalized() const
{
	mat3 n(*this);

	n.orthonormalize();

	return n;
}

// 'v' should be normalized
mat3 mat3::getRotateAngleAxis(float angleRad, const vec3& v)
{
	const float xx = v.x * v.x;
	const float xy = v.x * v.y;
	const float xz = v.x * v.z;

	const float yx = xy;
	const float yy = v.y * v.y;
	const float yz = v.y * v.z;

	const float zx = xz;
	const float zy = yz;
	const float zz = v.z * v.z;

	const float co = cosf(angleRad);
	const float si = sinf(angleRad);

	mat3 m;

	m[0][0] = xx + (1.0f - xx) * co;
	m[0][1] = xy * (1.0f - co) + v.z * si;
	m[0][2] = xz * (1.0f - co) - v.y * si;

	m[1][0] = yx * (1.0f - co) - v.z * si;
	m[1][1] = yy + (1.0f - yy) * co;
	m[1][2] = yz * (1.0f - co) + v.x * si;

	m[2][0] = zx * (1.0f - co) + v.y * si;
	m[2][1] = zy * (1.0f - co) - v.x * si;
	m[2][2] = zz + (1.0f - zz) * co;

	return m;
}

// https://iquilezles.org/articles/noacos/
// `v1` and `v2` should be normalized
mat3 mat3::getRotate(const vec3& v1, const vec3& v2)
{
	const vec3 v  = cross(v1, v2);
	const float c = dot(v1, v2);
	const float k = 1.0f / (1.0f + c);

	mat3 m;

	m[0][0] = v.x * v.x * k + c;
	m[0][1] = v.x * v.y * k + v.z;
	m[0][2] = v.x * v.z * k - v.y;

	m[1][0] = v.y * v.x * k - v.z;
	m[1][1] = v.y * v.y * k + c;
	m[1][2] = v.y * v.z * k + v.x;

	m[2][0] = v.z * v.x * k + v.y;
	m[2][1] = v.z * v.y * k - v.x;
	m[2][2] = v.z * v.z * k + c;

	return m;
}

namespace
{

// clang-format off
LFORCEINLINE float det33(
	float a11, float a12, float a13,
	float a21, float a22, float a23,
	float a31, float a32, float a33)
{
	return a11 * (a22 * a33 - a23 * a32) - a12 * (a21 * a33 - a31 * a23) + a13 * (a21 * a32 - a22 * a31);
}
// clang-format on

} // namespace

float mat4::det() const
{
	// clang-format off
	float d1 = det33(m[1][1], m[1][2], m[1][3],
	                 m[2][1], m[2][2], m[2][3],
	                 m[3][1], m[3][2], m[3][3]);

	float d2 = det33(m[1][0], m[1][2], m[1][3],
	                 m[2][0], m[2][2], m[2][3],
	                 m[3][0], m[3][2], m[3][3]);

	float d3 = det33(m[1][0], m[1][1], m[1][3],
	                 m[2][0], m[2][1], m[2][3],
	                 m[3][0], m[3][1], m[3][3]);

	float d4 = det33(m[1][0], m[1][1], m[1][2],
	                 m[2][0], m[2][1], m[2][2],
	                 m[3][0], m[3][1], m[3][2]);
	// clang-format on

	return m[0][0] * d1 - m[0][1] * d2 + m[0][2] * d3 - m[0][3] * d4;
}

void mat4::inverse()
{
#if defined(LMATH_USE_SSE4)

	// the SSE4 matrix inversion code based on ideas from https://lxjk.github.io/2017/09/03/Fast-4x4-Matrix-Inverse-with-SSE-SIMD-Explained.html
#define MakeShuffleMask(x, y, z, w) (x | (y << 2) | (z << 4) | (w << 6))
#define Swizzle(vec, x, y, z, w) _mm_shuffle_ps(vec, vec, MakeShuffleMask(x, y, z, w))
#define Swizzle1(vec, x) _mm_shuffle_ps(vec, vec, MakeShuffleMask(x, x, x, x))
#define Swizzle_0101(vec) _mm_movelh_ps(vec, vec)
#define Swizzle_2323(vec) _mm_movehl_ps(vec, vec)
#define Swizzle_0022(vec) _mm_moveldup_ps(vec)
#define Swizzle_1133(vec) _mm_movehdup_ps(vec)
#define VecShuffle(v1, v2, x, y, z, w) _mm_shuffle_ps(v1, v2, MakeShuffleMask(x, y, z, w))
#define VecShuffle_0101(v1, v2) _mm_movelh_ps(v1, v2)
#define VecShuffle_2323(v1, v2) _mm_movehl_ps(v2, v1)
#define Mat2Mul(v1, v2) _mm_add_ps(_mm_mul_ps(v1, Swizzle(v2, 0, 0, 3, 3)), _mm_mul_ps(Swizzle(v1, 2, 3, 0, 1), Swizzle(v2, 1, 1, 2, 2)))
#define Mat2AdjMul(v1, v2) _mm_sub_ps(_mm_mul_ps(Swizzle(v1, 3, 0, 3, 0), v2), _mm_mul_ps(Swizzle(v1, 2, 1, 2, 1), Swizzle(v2, 1, 0, 3, 2)))
#define Mat2MulAdj(v1, v2) _mm_sub_ps(_mm_mul_ps(v1, Swizzle(v2, 3, 3, 0, 0)), _mm_mul_ps(Swizzle(v1, 2, 3, 0, 1), Swizzle(v2, 1, 1, 2, 2)))

	float* LRESTRICT ptr = this->toFloatPtr();

	const __m128 v0   = _mm_loadu_ps(ptr + 0);
	const __m128 v1   = _mm_loadu_ps(ptr + 4);
	const __m128 v2   = _mm_loadu_ps(ptr + 8);
	const __m128 v3   = _mm_loadu_ps(ptr + 12);
	const __m128 A    = VecShuffle_0101(v0, v1);
	const __m128 C    = VecShuffle_2323(v0, v1);
	const __m128 B    = VecShuffle_0101(v2, v3);
	const __m128 D    = VecShuffle_2323(v2, v3);
	const __m128 detA = _mm_set1_ps(m[0][0] * m[1][1] - m[0][1] * m[1][0]);
	const __m128 detC = _mm_set1_ps(m[0][2] * m[1][3] - m[0][3] * m[1][2]);
	const __m128 detB = _mm_set1_ps(m[2][0] * m[3][1] - m[2][1] * m[3][0]);
	const __m128 detD = _mm_set1_ps(m[2][2] * m[3][3] - m[2][3] * m[3][2]);
	const __m128 D_C  = Mat2AdjMul(D, C);
	const __m128 A_B  = Mat2AdjMul(A, B);

	__m128 X_   = _mm_sub_ps(_mm_mul_ps(detD, A), Mat2Mul(B, D_C));
	__m128 W_   = _mm_sub_ps(_mm_mul_ps(detA, D), Mat2Mul(C, A_B));
	__m128 Y_   = _mm_sub_ps(_mm_mul_ps(detB, C), Mat2MulAdj(D, A_B));
	__m128 Z_   = _mm_sub_ps(_mm_mul_ps(detC, B), Mat2MulAdj(A, D_C));
	__m128 detM = _mm_add_ps(_mm_mul_ps(detA, detD), _mm_mul_ps(detB, detC));
	__m128 tr   = _mm_mul_ps(A_B, Swizzle(D_C, 0, 2, 1, 3));
	tr          = _mm_hadd_ps(tr, tr);
	tr          = _mm_hadd_ps(tr, tr);
	detM        = _mm_sub_ps(detM, tr);

	const __m128 invDet = _mm_div_ps(_mm_setr_ps(1.f, -1.f, -1.f, 1.f), detM);

	X_ = _mm_mul_ps(X_, invDet);
	Y_ = _mm_mul_ps(Y_, invDet);
	Z_ = _mm_mul_ps(Z_, invDet);
	W_ = _mm_mul_ps(W_, invDet);

	_mm_storeu_ps(ptr + 0, VecShuffle(X_, Z_, 3, 1, 3, 1));
	_mm_storeu_ps(ptr + 4, VecShuffle(X_, Z_, 2, 0, 2, 0));
	_mm_storeu_ps(ptr + 8, VecShuffle(Y_, W_, 3, 1, 3, 1));
	_mm_storeu_ps(ptr + 12, VecShuffle(Y_, W_, 2, 0, 2, 0));

#undef MakeShuffleMask
#undef Swizzle
#undef Swizzle1
#undef Swizzle_0101
#undef Swizzle_2323
#undef Swizzle_0022
#undef Swizzle_1133
#undef VecShuffle
#undef VecShuffle_0101
#undef VecShuffle_2323
#undef Mat2Mul
#undef Mat2AdjMul
#undef Mat2MulAdj

#else
	// 2x2 sub-determinants required to calculate the 4x4 determinant
	float d2_01_01 = m[0][0] * m[1][1] - m[0][1] * m[1][0];
	float d2_01_02 = m[0][0] * m[1][2] - m[0][2] * m[1][0];
	float d2_01_03 = m[0][0] * m[1][3] - m[0][3] * m[1][0];
	float d2_01_12 = m[0][1] * m[1][2] - m[0][2] * m[1][1];
	float d2_01_13 = m[0][1] * m[1][3] - m[0][3] * m[1][1];
	float d2_01_23 = m[0][2] * m[1][3] - m[0][3] * m[1][2];

	// 3x3 sub-determinants required to calculate the 4x4 determinant
	float d3_201_012 = m[2][0] * d2_01_12 - m[2][1] * d2_01_02 + m[2][2] * d2_01_01;
	float d3_201_013 = m[2][0] * d2_01_13 - m[2][1] * d2_01_03 + m[2][3] * d2_01_01;
	float d3_201_023 = m[2][0] * d2_01_23 - m[2][2] * d2_01_03 + m[2][3] * d2_01_02;
	float d3_201_123 = m[2][1] * d2_01_23 - m[2][2] * d2_01_13 + m[2][3] * d2_01_12;

	const float det = -d3_201_123 * m[3][0] + d3_201_023 * m[3][1] - d3_201_013 * m[3][2] + d3_201_012 * m[3][3];

	if (fabsf(det) < LMATH_EPSILON) {
		return;
	}

	const float invDet = 1.0f / det;

	// remaining 2x2 sub-determinants
	float d2_03_01 = m[0][0] * m[3][1] - m[0][1] * m[3][0];
	float d2_03_02 = m[0][0] * m[3][2] - m[0][2] * m[3][0];
	float d2_03_03 = m[0][0] * m[3][3] - m[0][3] * m[3][0];
	float d2_03_12 = m[0][1] * m[3][2] - m[0][2] * m[3][1];
	float d2_03_13 = m[0][1] * m[3][3] - m[0][3] * m[3][1];
	float d2_03_23 = m[0][2] * m[3][3] - m[0][3] * m[3][2];

	float d2_13_01 = m[1][0] * m[3][1] - m[1][1] * m[3][0];
	float d2_13_02 = m[1][0] * m[3][2] - m[1][2] * m[3][0];
	float d2_13_03 = m[1][0] * m[3][3] - m[1][3] * m[3][0];
	float d2_13_12 = m[1][1] * m[3][2] - m[1][2] * m[3][1];
	float d2_13_13 = m[1][1] * m[3][3] - m[1][3] * m[3][1];
	float d2_13_23 = m[1][2] * m[3][3] - m[1][3] * m[3][2];

	// remaining 3x3 sub-determinants
	float d3_203_012 = m[2][0] * d2_03_12 - m[2][1] * d2_03_02 + m[2][2] * d2_03_01;
	float d3_203_013 = m[2][0] * d2_03_13 - m[2][1] * d2_03_03 + m[2][3] * d2_03_01;
	float d3_203_023 = m[2][0] * d2_03_23 - m[2][2] * d2_03_03 + m[2][3] * d2_03_02;
	float d3_203_123 = m[2][1] * d2_03_23 - m[2][2] * d2_03_13 + m[2][3] * d2_03_12;

	float d3_213_012 = m[2][0] * d2_13_12 - m[2][1] * d2_13_02 + m[2][2] * d2_13_01;
	float d3_213_013 = m[2][0] * d2_13_13 - m[2][1] * d2_13_03 + m[2][3] * d2_13_01;
	float d3_213_023 = m[2][0] * d2_13_23 - m[2][2] * d2_13_03 + m[2][3] * d2_13_02;
	float d3_213_123 = m[2][1] * d2_13_23 - m[2][2] * d2_13_13 + m[2][3] * d2_13_12;

	float d3_301_012 = m[3][0] * d2_01_12 - m[3][1] * d2_01_02 + m[3][2] * d2_01_01;
	float d3_301_013 = m[3][0] * d2_01_13 - m[3][1] * d2_01_03 + m[3][3] * d2_01_01;
	float d3_301_023 = m[3][0] * d2_01_23 - m[3][2] * d2_01_03 + m[3][3] * d2_01_02;
	float d3_301_123 = m[3][1] * d2_01_23 - m[3][2] * d2_01_13 + m[3][3] * d2_01_12;

	m[0][0] = -d3_213_123 * invDet;
	m[1][0] = +d3_213_023 * invDet;
	m[2][0] = -d3_213_013 * invDet;
	m[3][0] = +d3_213_012 * invDet;

	m[0][1] = +d3_203_123 * invDet;
	m[1][1] = -d3_203_023 * invDet;
	m[2][1] = +d3_203_013 * invDet;
	m[3][1] = -d3_203_012 * invDet;

	m[0][2] = +d3_301_123 * invDet;
	m[1][2] = -d3_301_023 * invDet;
	m[2][2] = +d3_301_013 * invDet;
	m[3][2] = -d3_301_012 * invDet;

	m[0][3] = -d3_201_123 * invDet;
	m[1][3] = +d3_201_023 * invDet;
	m[2][3] = -d3_201_013 * invDet;
	m[3][3] = +d3_201_012 * invDet;
#endif // LMATH_USE_SSE4
}

mat4 mat4::getInversed() const
{
	mat4 inv(*this);

	inv.inverse();

	return inv;
}

void mat4::transpose()
{
	for (size_t i = 0; i != 4; i++) {
		for (size_t j = 0; j != 4; j++) {
			const float tmp = m[i][j];
			m[i][j]         = m[j][i];
			m[j][i]         = tmp;
		}
	}
}

mat4 mat4::getTransposed() const
{
	mat4 t;

	for (size_t i = 0; i != 4; i++)
		for (size_t j = 0; j != 4; j++)
			t[i][j] = m[j][i];

	return t;
}

mat4 mat4::getRotateAngleAxis(float angleRad, const vec3& axisNormalized)
{
	const mat3 m = mat3::getRotateAngleAxis(angleRad, axisNormalized);
	return mat4(m);
}
mat4 mat4::getRotate(const vec3& v1, const vec3& v2)
{
	const mat3 m = mat3::getRotate(v1, v2);
	return mat4(m);
}

mat4 mat4::getTranslate(const vec3& v)
{
	mat4 m;
	m[0] = vec4(1.0f, 0.0f, 0.0f, 0.0f);
	m[1] = vec4(0.0f, 1.0f, 0.0f, 0.0f);
	m[2] = vec4(0.0f, 0.0f, 1.0f, 0.0f);
	m[3] = vec4(v, 1.0f);
	return m;
}

mat4 mat4::getScale(const vec3& v)
{
	mat4 m;
	m[0] = vec4(v.x, 0.0f, 0.0f, 0.0f);
	m[1] = vec4(0.0f, v.y, 0.0f, 0.0f);
	m[2] = vec4(0.0f, 0.0f, v.z, 0.0f);
	m[3] = vec4(0.0f, 0.0f, 0.0f, 1.0f);
	return m;
}

mat4 mat4::getFromPitchPanRoll(float degPitch, float degPan, float degRoll)
{
	const mat4 roll  = mat4::getRotateAngleAxis(degRoll * LMATH_DTOR, vec3(0, 1, 0));
	const mat4 pan   = mat4::getRotateAngleAxis(degPan * LMATH_DTOR, vec3(1, 0, 0));
	const mat4 pitch = mat4::getRotateAngleAxis(degPitch * LMATH_DTOR, vec3(0, 0, 1));

	return pitch * pan * roll;
}

} // namespace ldr
