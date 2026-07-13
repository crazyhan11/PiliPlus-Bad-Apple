/**
 * \file cvar.cpp
 * \brief
 *
 * CVars
 *
 * \version 1.0.1
 * \date 11/06/2023
 * \author Sergey Kosarevsky, 2022-2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#include "CVar.h"

// clang-format off
#if !defined(_MSC_VER)
#  include <strings.h>
#endif // !defined(_MSC_VER)

#if defined(ANDROID) || defined(__APPLE__) || defined(__linux__)
#  define stricmp strcasecmp
#endif
// clang-format on

#include <algorithm>

namespace ldr {

int CVar::getConvertedToInt() const {
  if (flags_ & eCVarTypeFlags_Int)
    return int_;

  switch (type_) {
  case eCVarType_Int:
    return int_;
  case eCVarType_Bool:
    return bool_ ? 1 : 0;
  case eCVarType_Double:
    return (int)double_;
  case eCVarType_Float:
  case eCVarType_Vec2:
  case eCVarType_Vec3:
  case eCVarType_Vec4:
    return (int)float_[0];
  case eCVarType_String:
    return atoi(string_.c_str());
  }

  return 0;
}

bool CVar::getConvertedToBool() const {
  if (flags_ & eCVarTypeFlags_Bool)
    return bool_;

  switch (type_) {
  case eCVarType_Int:
    return int_ > 0;
  case eCVarType_Bool:
    return bool_;
  case eCVarType_Double:
    return double_ > 0;
  case eCVarType_Float:
  case eCVarType_Vec2:
  case eCVarType_Vec3:
  case eCVarType_Vec4:
    return float_[0] > 0;
  case eCVarType_String:
    return stricmp(string_.c_str(), "false") != 0;
  }

  return false;
}

float CVar::getConvertedToFloat() const {
  if (flags_ & eCVarTypeFlags_Float)
    return float_[0];

  switch (type_) {
  case eCVarType_Int:
    return (float)int_;
  case eCVarType_Bool:
    return bool_ ? 1.0f : 0.0f;
  case eCVarType_Double:
    return (float)double_;
  case eCVarType_Float:
  case eCVarType_Vec2:
  case eCVarType_Vec3:
  case eCVarType_Vec4:
    return float_[0];
  case eCVarType_String:
    return atof(string_.c_str());
  }

  return 0;
}

double CVar::getConvertedToDouble() const {
  if (flags_ & eCVarTypeFlags_Double)
    return double_;

  switch (type_) {
  case eCVarType_Int:
    return (double)int_;
  case eCVarType_Bool:
    return bool_ ? 1.0 : 0.0;
  case eCVarType_Double:
    return double_;
  case eCVarType_Float:
  case eCVarType_Vec2:
  case eCVarType_Vec3:
  case eCVarType_Vec4:
    return float_[0];
  case eCVarType_String:
    return atof(string_.c_str());
  }

  return 0;
}

void CVar::getConvertedToVector(float* out) const {
  switch (type_) {
  case eCVarType_Int:
    out[0] = (float)int_;
    out[1] = 0.0f;
    out[2] = 0.0f;
    out[3] = 0.0f;
    return;
  case eCVarType_Bool:
    out[0] = bool_ ? 1.0f : 0.0f;
    out[1] = 0.0f;
    out[2] = 0.0f;
    out[3] = 0.0f;
    return;
  case eCVarType_Double:
    out[0] = (float)double_;
    out[1] = 0.0f;
    out[2] = 0.0f;
    out[3] = 0.0f;
    return;
  case eCVarType_Float:
    return;
  case eCVarType_Vec2:
    return;
  case eCVarType_Vec3:
    return;
  case eCVarType_Vec4:
    return;
  case eCVarType_String:
    out[0] = out[1] = out[2] = out[3] = 0.0f;
    sscanf(string_.c_str(), "%f %f %f %f", &out[0], &out[1], &out[2], &out[3]);
  }
}

std::string CVar::getConvertedToString() const {
  if (flags_ & eCVarTypeFlags_String)
    return string_;

  char buf[128] = {};

  switch (type_) {
  case eCVarType_Int:
    return std::to_string(int_);
  case eCVarType_Bool:
    return bool_ ? "TRUE" : "FALSE";
  case eCVarType_Double:
    snprintf(buf, sizeof(buf) - 1, "%.9f", double_);
    return std::string(buf);
  case eCVarType_Float:
    snprintf(buf, sizeof(buf) - 1, "%.9f", float_[0]);
    return std::string(buf);
  case eCVarType_Vec2:
    snprintf(buf, sizeof(buf) - 1, "%.9f %.9f", float_[0], float_[1]);
    return std::string(buf);
  case eCVarType_Vec3:
    snprintf(buf, sizeof(buf) - 1, "%.9f %.9f %.9f", float_[0], float_[1], float_[2]);
    return std::string(buf);
  case eCVarType_Vec4:
    snprintf(buf, sizeof(buf) - 1, "%.9f %.9f %.9f %.9f", float_[0], float_[1], float_[2], float_[3]);
    return std::string(buf);
  case eCVarType_String:
    return string_;
  }

  return std::string();
}

int CVar::getInt() const {
  if (flags_ & eCVarTypeFlags_Int)
    return int_;

  int_ = getConvertedToInt();
  flags_ |= eCVarTypeFlags_Int;

  return int_;
}

float CVar::getFloat() const {
  if (flags_ & eCVarTypeFlags_Float)
    return float_[0];

  const float f = getConvertedToFloat();

  float_[0] = f;
  double_ = f;
  flags_ |= eCVarTypeFlags_Float | eCVarTypeFlags_Double;

  return float_[0];
}

double CVar::getDouble() const {
  if (flags_ & eCVarTypeFlags_Double)
    return double_;

  const double f = getConvertedToDouble();

  float_[0] = f;
  double_ = f;
  flags_ |= eCVarTypeFlags_Float | eCVarTypeFlags_Double;

  return double_;
}

bool CVar::getBool() const {
  if (flags_ & eCVarTypeFlags_Bool)
    return bool_;

  bool_ = getConvertedToBool();
  flags_ |= eCVarTypeFlags_Bool;

  return bool_;
}

const float* CVar::getVector() const {
  if (flags_ & eCVarTypeFlags_Float)
    return float_;

  getConvertedToVector(float_);

  flags_ |= eCVarTypeFlags_Float;

  return float_;
}

std::string CVar::getString() const {
  if (flags_ & eCVarTypeFlags_String)
    return string_;

  string_ = getConvertedToString();
  flags_ |= eCVarTypeFlags_String;

  return string_;
}

void CVar::setInt(int v) {
  const bool isChanged = (int_ != v) || (type_ != eCVarType_Int);

  int_ = v;
  type_ = eCVarType_Int;
  flags_ = eCVarTypeFlags_Int;

  if (isChanged)
    invokeListeners();
}

void CVar::setBool(bool v) {
  const bool isChanged = (bool_ != v) || (type_ != eCVarType_Bool);

  bool_ = v;
  type_ = eCVarType_Bool;
  flags_ = eCVarTypeFlags_Bool;

  if (isChanged)
    invokeListeners();
}

void CVar::setFloat(float v) {
  const bool isChanged = (float_[0] != v) || (type_ != eCVarType_Float);

  float_[0] = v;
  float_[1] = 0.0f;
  float_[2] = 0.0f;
  float_[3] = 0.0f;

  type_ = eCVarType_Float;
  flags_ = eCVarTypeFlags_Float;

  if (isChanged)
    invokeListeners();
}

void CVar::setDouble(double v) {
  const bool isChanged = (double_ != v) || (type_ != eCVarType_Double);

  double_ = v;

  type_ = eCVarType_Double;
  flags_ = eCVarTypeFlags_Double;

  if (isChanged)
    invokeListeners();
}

void CVar::setVec2(const float* v) {
  const bool isChanged = (float_[0] != v[0]) || (float_[1] != v[1]) || (type_ != eCVarType_Vec2);

  float_[0] = v[0];
  float_[1] = v[1];
  float_[2] = 0.0f;
  float_[3] = 0.0f;
  type_ = eCVarType_Vec2;
  flags_ = eCVarTypeFlags_Float;

  if (isChanged)
    invokeListeners();
}

void CVar::setVec3(const float* v) {
  const bool isChanged = (float_[0] != v[0]) || (float_[1] != v[1]) || (float_[2] != v[2]) || (type_ != eCVarType_Vec3);

  float_[0] = v[0];
  float_[1] = v[1];
  float_[2] = v[2];
  float_[3] = 0.0f;
  type_ = eCVarType_Vec3;
  flags_ = eCVarTypeFlags_Float;

  if (isChanged)
    invokeListeners();
}

void CVar::setVec4(const float* v) {
  const bool isChanged = (float_[0] != v[0]) || (float_[1] != v[1]) || (float_[2] != v[2]) || (float_[3] != v[3]) ||
                         (type_ != eCVarType_Vec4);

  float_[0] = v[0];
  float_[1] = v[1];
  float_[2] = v[2];
  float_[3] = v[3];
  type_ = eCVarType_Vec4;
  flags_ = eCVarTypeFlags_Float;

  if (isChanged)
    invokeListeners();
}

void CVar::setString(const std::string& v) {
  const bool isChanged = (string_ != v) || (type_ != eCVarType_String);

  string_ = v;
  type_ = eCVarType_String;
  flags_ = eCVarTypeFlags_String;

  if (isChanged)
    invokeListeners();
}

void CVar::listenerAdd(iCVarChangedListener* l) {
  listeners_.push_back(l);
}

void CVar::listenerRemove(iCVarChangedListener* l) {
  listeners_.erase(std::remove(listeners_.begin(), listeners_.end(), l), listeners_.end());
}

void CVar::invokeListeners() {
  for (iCVarChangedListener* l : listeners_)
    l->cvarChanged(this);
}

} // namespace ldr
