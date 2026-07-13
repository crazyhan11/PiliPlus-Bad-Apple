/**
 * \file Handle.h
 * \brief Lightweight non-ref-counted generational handles
 *
 * \author Sergey Kosarevsky, 2026
 * \author sk@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <cstdint>

#include "Macros.h"

namespace ldr {

// Non-ref counted handles (uint32_t and uint16_t)
// Based on https://enginearchitecture.realtimerendering.com/downloads/reac2023_modern_mobile_rendering_at_hypehype.pdf
template<typename HandleTag, typename IndexType = uint32_t>
class Handle final {
  static_assert(sizeof(IndexType) >= sizeof(uint16_t) && sizeof(IndexType) <= sizeof(uint32_t), "Unsupported IndexType size");

 public:
  Handle() = default;
  explicit Handle(void* ptr)
  : index_(static_cast<IndexType>(reinterpret_cast<uintptr_t>(ptr)))
  , gen_(static_cast<IndexType>(static_cast<uint64_t>(reinterpret_cast<uintptr_t>(ptr)) >> (sizeof(IndexType) * 8))) {
    static_assert(sizeof(void*) >= sizeof(IndexType) * 2, "Packing a handle into a pointer requires a pointer twice the index width");
  }

  LFORCEINLINE bool empty() const {
    return gen_ == 0;
  }
  LFORCEINLINE bool valid() const {
    return gen_ != 0;
  }
  LFORCEINLINE IndexType index() const {
    return index_;
  }
  LFORCEINLINE IndexType gen() const {
    return gen_;
  }
  LFORCEINLINE void* indexAsVoid() const {
    return reinterpret_cast<void*>(static_cast<uintptr_t>(index_));
  }
  LFORCEINLINE void* handleAsVoid() const {
    static_assert(sizeof(void*) >= sizeof(IndexType) * 2, "Packing a handle into a pointer requires a pointer twice the index width");
    return reinterpret_cast<void*>(static_cast<uintptr_t>((static_cast<uint64_t>(gen_) << (sizeof(IndexType) * 8)) | index_));
  }
  LFORCEINLINE bool operator==(const Handle<HandleTag, IndexType>& other) const {
    return index_ == other.index_ && gen_ == other.gen_;
  }
  LFORCEINLINE bool operator!=(const Handle<HandleTag, IndexType>& other) const {
    return index_ != other.index_ || gen_ != other.gen_;
  }
  // allow conditions 'if (handle)'
  LFORCEINLINE explicit operator bool() const {
    return gen_ != 0;
  }

 private:
  Handle(IndexType index, IndexType gen) : index_(index), gen_(gen) {}

  template<typename PoolHandleTag, typename ObjectType, typename PoolIndexType>
  friend class Pool;

  IndexType index_ = 0;
  IndexType gen_ = 0;
};

static_assert(sizeof(Handle<class Foo>) == sizeof(uint64_t));

} // namespace ldr
