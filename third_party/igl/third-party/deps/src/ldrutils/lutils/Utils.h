/**
 * \file Utils.h
 * \brief
 *
 * Various utility functions
 *
 * \version 1.0.0
 * \date 30/03/2023
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

namespace ldr {

// works with std::deque etc
template<class T>
[[nodiscard]] typename T::value_type pop_front(T& container) {
  const typename T::value_type value = std::move(container.front());
  container.pop_front();
  return value;
}

} // namespace ldr
