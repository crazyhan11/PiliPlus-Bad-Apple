/**
 * \file cvar.h
 * \brief
 *
 * CVars
 *
 * \version 1.0.0
 * \date 08/06/2022
 * \author Sergey Kosarevsky, 2022
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <stdint.h>
#include <string>
#include <vector>

namespace ldr {

class CVar;

enum eCVarType {
  eCVarType_Int,
  eCVarType_Bool,
  eCVarType_Double,
  eCVarType_Float,
  eCVarType_Vec2,
  eCVarType_Vec3,
  eCVarType_Vec4,
  eCVarType_String,
};

enum eCVarTypeFlags {
  eCVarTypeFlags_Int = 0x01,
  eCVarTypeFlags_Bool = 0x02,
  eCVarTypeFlags_Double = 0x04,
  eCVarTypeFlags_Float = 0x08,
  eCVarTypeFlags_String = 0x10,
};

class iCVarChangedListener {
 public:
  virtual ~iCVarChangedListener() = default;
  virtual void cvarChanged(CVar* v) = 0;
};

class CVar final {
 public:
  CVar() = default;

  eCVarType getType() const {
    return type_;
  }

  int getInt() const;
  bool getBool() const;
  float getFloat() const;
  double getDouble() const;
  const float* getVector() const;
  std::string getString() const;

  void setInt(int v);
  void setBool(bool v);
  void setFloat(float v);
  void setDouble(double v);
  void setVec2(const float* v);
  void setVec3(const float* v);
  void setVec4(const float* v);
  void setString(const std::string& v);

  void listenerAdd(iCVarChangedListener* l);
  void listenerRemove(iCVarChangedListener* l);

 private:
  void invokeListeners();

  int getConvertedToInt() const;
  bool getConvertedToBool() const;
  float getConvertedToFloat() const;
  double getConvertedToDouble() const;
  std::string getConvertedToString() const;
  void getConvertedToVector(float* out) const;

 private:
  eCVarType type_ = eCVarType_Int;
  mutable uint32_t flags_ = eCVarTypeFlags_Int | eCVarTypeFlags_Bool | eCVarTypeFlags_Float | eCVarTypeFlags_Double;
  std::vector<iCVarChangedListener*> listeners_;
  //
  mutable int int_ = 0;
  mutable bool bool_ = false;
  mutable float float_[4] = {0};
  mutable double double_ = {0};
  mutable std::string string_;
};

} // namespace ldr
