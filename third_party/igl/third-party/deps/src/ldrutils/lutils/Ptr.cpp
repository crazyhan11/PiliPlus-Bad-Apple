/**
 * \file ptr.cpp
 * \brief
 *
 * Minimalistic intrusive smartpointer
 *
 * \version 1.0.0
 * \date 16/09/2022
 * \author Sergey Kosarevsky, 2022
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#include "Ptr.h"

#include <assert.h>

// clang-format off
#if defined(_MSC_VER)
#	define WIN32_LEAN_AND_MEAN
#	define VC_EXTRALEAN
#	define NOMINMAX
#	include <windows.h>
#endif // _MSC_VER
// clang-format on

void ldr::IntrusiveCounter::incRef(void* p) {
  if (p) {
    reinterpret_cast<ldr::IntrusiveCounter*>(p)->incRefCount();
  }
}

void ldr::IntrusiveCounter::decRef(void* p) {
  if (p) {
    reinterpret_cast<ldr::IntrusiveCounter*>(p)->decRefCount();
  }
}

void ldr::IntrusiveCounter::incRefCount() {
#if defined(_MSC_VER)
  InterlockedIncrement(&refCounter_);
#else
  __sync_fetch_and_add(&refCounter_, 1);
#endif // _MSC_VER
}

void ldr::IntrusiveCounter::decRefCount() {
  assert(refCounter_ > 0);

  if (0 ==
#if defined(_MSC_VER)
      InterlockedDecrement(&refCounter_)
#else
      __sync_sub_and_fetch(&refCounter_, 1)
#endif // _MSC_VER
  ) {
    delete this;
  }
}
