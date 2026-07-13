/**
 * \file ScopeExit.h
 * \brief
 *
 * SCOPE_EXIT macro
 *
 * \version 1.0.0
 * \date 12/07/2023
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

// based on CppCon 2015: Andrei Alexandrescu "Declarative Control Flow"
// clang-format off
#ifndef LDR_ANONYMOUS_VARIABLE
# define LDR_CONCATENATE_IMPL(s1, s2) s1##s2
# define LDR_CONCATENATE(s1, s2) LDR_CONCATENATE_IMPL(s1, s2)
# ifdef __COUNTER__
#  define LDR_ANONYMOUS_VARIABLE(str) LDR_CONCATENATE(str, __COUNTER__)
# else
#  define LDR_ANONYMOUS_VARIABLE(str) LDR_CONCATENATE(str, __LINE__)
# endif
#endif // LDR_ANONYMOUS_VARIABLE
// clang-format on

namespace {

enum class ScopeGuardOnExit {};

template<typename T>
class ScopeGuard {
 public:
  explicit ScopeGuard(T&& fn) : fn_(std::move(fn)) {}
  ~ScopeGuard() {
    fn_();
  }

 private:
  T fn_;
};

template<typename T>
ScopeGuard<T> operator+(ScopeGuardOnExit, T&& fn) {
  return ScopeGuard<T>(std::forward<T>(fn));
}

} // namespace

#define SCOPE_EXIT auto LDR_ANONYMOUS_VARIABLE(SCOPE_EXIT_STATE) = ScopeGuardOnExit() + [&]() noexcept
