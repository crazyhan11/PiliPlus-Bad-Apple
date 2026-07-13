/**
 * \file Math.h
 * \brief
 *
 * Math utilities
 *
 * \version 1.0.1
 * \date 23/06/2026
 * \author Sergey Kosarevsky, 2023-2026
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <cmath>
#include <stddef.h>
#include <stdint.h>

#include "lutils/Macros.h"

#define LMATH_INFINITY 1e30f
#define LMATH_EPSILON 1e-8f
#define LMATH_PI 3.14159265358979323846f
#define LMATH_TWOPI 6.28318530717958647692f
#define LMATH_HALFPI 1.57079632679489661923f
#define LMATH_SQRT2 1.41421356237309504880f
// Pi/180
#define LMATH_DTOR 0.01745329251994329577f
// 180/Pi
#define LMATH_RTOD 57.29577951308232087679f

namespace ldr {

[[nodiscard]] LFORCEINLINE float absf(float v) {
  return (v > 0.0f) ? v : -v;
}

[[nodiscard]] LFORCEINLINE float minf(float a, float b) {
  return (a < b) ? a : b;
}

[[nodiscard]] LFORCEINLINE float maxf(float a, float b) {
  return (a > b) ? a : b;
}

[[nodiscard]] LFORCEINLINE float degToRad(float deg) {
  return deg * LMATH_DTOR;
}

[[nodiscard]] LFORCEINLINE float radToDeg(float rad) {
  return rad * LMATH_RTOD;
}

LFORCEINLINE void swapf(float& v1, float& v2) {
  const float tmp = v1;

  v1 = v2;
  v2 = tmp;
}

[[nodiscard]] LFORCEINLINE float signf(float x) {
  return (x > 0) ? 1.0f : -1.0f;
}

// note: returns `true` for 0
[[nodiscard]] LFORCEINLINE bool isPowerOf2(uint32_t n) {
  return (n & (n - 1)) == 0;
}

// note: returns `true` for 0
[[nodiscard]] LFORCEINLINE bool isPowerOf2(uint64_t n) {
  return (n & (n - 1)) == 0;
}

// note: return 0 on overflow
[[nodiscard]] LFORCEINLINE uint32_t getNextPowerOf2(uint32_t n) {
  n |= (n >> 1);
  n |= (n >> 2);
  n |= (n >> 4);
  n |= (n >> 8);
  n |= (n >> 16);
  return n + 1;
}

// note: return 0 on overflow
[[nodiscard]] LFORCEINLINE uint64_t getNextPowerOf2(uint64_t n) {
  n |= (n >> 1);
  n |= (n >> 2);
  n |= (n >> 4);
  n |= (n >> 8);
  n |= (n >> 16);
  n |= (n >> 32);
  return n + 1;
}

// floating-point division remainder (wrap around negative values)
[[nodiscard]] LFORCEINLINE float modf(float a, float b) {
  a -= b * floor(a / b);
  return (a < 0) ? a + b : a;
}

// integer division remainder (wrap around negative values)
[[nodiscard]] LFORCEINLINE int modi(int a, int b) {
  const int r = a % b;
  return (r < 0) ? r + b : r;
}

template<typename T>
[[nodiscard]] LFORCEINLINE T clamp(T x, T minVal, T maxVal) {
  if (x > maxVal)
    return maxVal;
  if (x < minVal)
    return minVal;
  return x;
}

[[nodiscard]] LFORCEINLINE float clampfPeriodic(float x, float minVal, float maxVal) {
  if (x > maxVal)
    return minVal + ldr::modf(x - minVal, maxVal - minVal);
  if (x < minVal)
    return maxVal - ldr::modf(minVal - x, maxVal - minVal);
  return x;
}

// GLSL step()
[[nodiscard]] LFORCEINLINE float step(float edge, float x) {
  return x < edge ? 0.0f : 1.0f;
}

// GLSL smoothstep()
[[nodiscard]] LFORCEINLINE float smoothStep(float edge0, float edge1, float x) {
  if (x <= edge0)
    return 0.0f;
  if (x >= edge1)
    return 1.0f;
  const float t = (x - edge0) / (edge1 - edge0);
  return t * t * (3.0f - 2.0f * t);
}

[[nodiscard]] LFORCEINLINE float lerp(float a, float b, float x) {
  return std::fmaf(x, b - a, a);
}

[[nodiscard]] LFORCEINLINE double lerp(double a, double b, float x) {
  return std::fma(x, b - a, a);
}

template<class T>
[[nodiscard]] LFORCEINLINE T lerp(const T& a, const T& b, float x) {
  return x * (b - a) + a;
}

// note: degrees
template<class T>
[[nodiscard]] LFORCEINLINE T clipAngleTo0_360(T angle) {
  return std::fmod(angle, T(360));
}

[[nodiscard]] LFORCEINLINE float vecToAngle(float x, float y) {
  return 180.0f + ldr::radToDeg(atan2(y, x));
}

/// 4-byte integer hashing: http://burtleburtle.net/bob/hash/integer.html
[[nodiscard]] inline uint32_t hash_uint32(uint32_t v) {
  v = (v ^ 61) ^ (v >> 16);
  v = v + (v << 3);
  v = v ^ (v >> 4);
  v = v * 0x27d4eb2d;
  v = v ^ (v >> 15);
  return v;
}

} // namespace ldr
