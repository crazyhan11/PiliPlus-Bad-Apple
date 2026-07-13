/**
 * \file DynamicLibrary.h
 * \brief
 *
 * Cross-platform dynamic link libraries (.dll/.so)
 *
 * \version 1.0.0
 * \date 13/03/2023
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

namespace ldr {

/// Cross-platform dynamic link libraries
class DynamicLibrary {
 public:
  DynamicLibrary() = default;
  ~DynamicLibrary();

  void* getProcAddress(const char* procName) const;
  bool load(const char* fileName);
  bool isLoaded() const {
    return handle_ != nullptr;
  }

 private:
  void* handle_ = nullptr;
};

} // namespace ldr
