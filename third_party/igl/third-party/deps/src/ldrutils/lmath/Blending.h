/**
 * \file Blending.h
 * \brief
 *
 * Bitmaps blending operators
 *
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include "lmath/Math.h"

namespace ldr {

inline float blend_Normal(float base, float overlay) {
  return base;
}
inline float blend_Lighten(float base, float overlay) {
  return (overlay > base) ? overlay : base;
}
inline float blend_Darken(float base, float overlay) {
  return (overlay > base) ? base : overlay;
}
inline float blend_Multiply(float base, float overlay) {
  return base * overlay;
}
inline float blend_Average(float base, float overlay) {
  return (base + overlay) / 2.0f;
}
inline float blend_Add(float base, float overlay) {
  return ldr::minf(base + overlay, 1.0f);
}
inline float blend_Subtract(float base, float overlay) {
  return ldr::maxf(base + overlay - 1.0f, 0.0f);
}
inline float blend_Difference(float base, float overlay) {
  return ldr::absf(base - overlay);
}
inline float blend_Negation(float base, float overlay) {
  return 1.0f - ldr::absf(1.0f - base - overlay);
}
inline float blend_Screen(float base, float overlay) {
  return 1.0f - (1.0f - base) * (1.0f - overlay);
}
inline float blend_Exclusion(float base, float overlay) {
  return base + overlay - 2 * base * overlay;
}
inline float blend_Overlay(float base, float overlay) {
  return (overlay < 0.5f) ? (2.0f * base * overlay) : (2.0f * base - 1.0f) * (1.0f - overlay);
}
inline float blend_SoftLight(float base, float overlay) {
  return (overlay < 0.5f) ? (base + 0.5f) * overlay : (base - 0.5f) * (1.0f - overlay);
}
inline float blend_HardLight(float base, float overlay) {
  return blend_Overlay(overlay, base);
}
inline float blend_ColorDodge(float base, float overlay) {
  return (overlay > 1.0f - LMATH_EPSILON) ? overlay : ldr::minf(1.0f, base / (1.0f - overlay));
}
inline float blend_ColorBurn(float base, float overlay) {
  return (overlay < LMATH_EPSILON) ? overlay : ldr::maxf(0.0f, 1.0f - (1.0f - base) / overlay);
}
inline float blend_LinearDodge(float base, float overlay) {
  return blend_Add(base, overlay);
}
inline float blend_LinearBurn(float base, float overlay) {
  return blend_Subtract(base, overlay);
}
inline float blend_LinearLight(float base, float overlay) {
  return (overlay < 0.5f) ? blend_LinearBurn(base, 2 * overlay) : blend_LinearDodge(base, (2.0f * (overlay - 0.5f)));
}
inline float blend_VividLight(float base, float overlay) {
  return (overlay < 0.5f) ? blend_ColorBurn(base, 2 * overlay) : blend_ColorDodge(base, (2.0f * (overlay - 0.5f)));
}
inline float blend_PinLight(float base, float overlay) {
  return (overlay < 0.5f) ? blend_Darken(base, 2 * overlay) : blend_Lighten(base, (2.0f * (overlay - 0.5f)));
}
inline float blend_HardMix(float base, float overlay) {
  return (blend_VividLight(base, overlay) < 0.5f) ? 0.0f : 1.0f;
}
inline float blend_Reflect(float base, float overlay) {
  return (overlay > 1.0f - LMATH_EPSILON) ? overlay : ldr::minf(1.0f, base * base / (1.0f - overlay));
}
inline float blend_Glow(float base, float overlay) {
  return blend_Reflect(overlay, base);
}
inline float blend_Phoenix(float base, float overlay) {
  return ldr::minf(base, overlay) - ldr::maxf(base, overlay) + 1.0f;
}

} // namespace ldr
