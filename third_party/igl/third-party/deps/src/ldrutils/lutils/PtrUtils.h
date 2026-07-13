/**
 * \file Ptr.h
 * \brief
 *
 * Minimalistic intrusive smartpointer - utils
 *
 * \version 1.0.0
 * \date 16/09/2022
 * \author Sergey Kosarevsky, 2022
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include "Ptr.h"

#include <utility>

namespace ldr {

template<class T, class... Args>
clPtr<T> make_intrusive(Args&&... args) {
  return clPtr<T>(new T(std::forward<Args>(args)...));
}

} // namespace ldr
