/**
 * \file Pool.h
 * \brief Generational object pool with free-list slot recycling, accessed through Handle<>
 *
 * \author Sergey Kosarevsky, 2026
 * \author sk@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <assert.h>
#include <cstdint>
#include <vector>

#include "Handle.h"
#include "Macros.h"

namespace ldr {

// a simple IsSame_v implementation to avoid including <type_traits>
template<typename T, typename U>
struct IsSame {
  static constexpr bool value = false;
};
template<typename T>
struct IsSame<T, T> {
  static constexpr bool value = true;
};
template<typename T, typename U>
inline constexpr bool IsSame_v = IsSame<T, U>::value;

template<typename HandleTag, typename ObjectType, typename IndexType = uint32_t>
class Pool {
  static_assert(IsSame_v<IndexType, uint16_t> || IsSame_v<IndexType, uint32_t>, "Unsupported IndexType");
  enum : IndexType { kListEndSentinel = static_cast<IndexType>(IsSame_v<IndexType, uint16_t> ? 0xffff : 0xffffffff) };
  using HandleType = Handle<HandleTag, IndexType>;
  struct Metadata {
    IndexType nextFree_ = kListEndSentinel;
    IndexType gen_ = 1;
  };
  IndexType freeListHead_ = kListEndSentinel;
  IndexType numObjects_ = 0;
  std::vector<Metadata> meta_;

 public:
  std::vector<ObjectType> objects_;

  Pool() = default;
  explicit Pool(IndexType numSlotsToReserve) {
    meta_.reserve(numSlotsToReserve);
    objects_.reserve(numSlotsToReserve);
  }
  // copying a Pool would duplicate all objects while existing Handles keep aliasing both copies - disallow it
  Pool(const Pool&) = delete;
  Pool& operator=(const Pool&) = delete;
  Pool(Pool&&) = default;
  Pool& operator=(Pool&&) = default;

  HandleType create(ObjectType&& obj) {
    IndexType idx = 0;
    if (freeListHead_ != kListEndSentinel) {
      idx = freeListHead_;
      freeListHead_ = meta_[idx].nextFree_;
      objects_[idx] = std::move(obj);
    } else {
      assert(objects_.size() < kListEndSentinel); // out of free slots: index would collide with kListEndSentinel or overflow IndexType
      idx = static_cast<IndexType>(objects_.size());
      objects_.emplace_back(std::move(obj));
      meta_.push_back({});
    }
    numObjects_++;
    return HandleType(idx, meta_[idx].gen_);
  }
  // PERFORMANCE NOTE: all generation checks below are asserts only - in release builds an out-of-date Handle (one whose slot has since
  // been destroyed and possibly reused) is not detected and dereferencing it returns a pointer to whatever object now occupies that slot.
  // Callers must not retain Handles past the lifetime of the object they refer to.
  void destroy(HandleType handle) {
    if (handle.empty())
      return;
    assert(numObjects_ > 0); // double deletion
    const IndexType index = handle.index();
    assert(index < objects_.size());
    assert(handle.gen() == meta_[index].gen_); // double deletion
    objects_[index] = ObjectType{};
    meta_[index].gen_++;
    // skip generation 0 on wraparound: gen 0 is reserved for the null Handle, so a reused slot must never produce it
    if (!meta_[index].gen_)
      meta_[index].gen_ = 1;
    meta_[index].nextFree_ = freeListHead_;
    freeListHead_ = index;
    numObjects_--;
  }
  const ObjectType* get(HandleType handle) const {
    if (handle.empty())
      return nullptr;

    const IndexType index = handle.index();
    assert(index < objects_.size());
    assert(handle.gen() == meta_[index].gen_); // accessing deleted object
    return &objects_[index];
  }
  // delegate to the const overload to avoid duplicating the lookup; const_cast is safe because *this is non-const here
  LFORCEINLINE ObjectType* get(HandleType handle) {
    return const_cast<ObjectType*>(static_cast<const Pool*>(this)->get(handle));
  }
  // PERFORMANCE NOTE: this builds a handle from any in-range index without checking whether the slot is alive, so it can return a
  // valid-looking handle to a freed or never-initialized slot (the handle carries the slot's current generation and will pass get()'s
  // assert). Callers must only pass indices known to refer to live objects.
  HandleType getHandle(IndexType index) const {
    assert(index < objects_.size());
    if (index >= objects_.size())
      return {};

    return HandleType(index, meta_[index].gen_);
  }
  // PERFORMANCE NOTE: this scans every slot, including freed ones (destroyed slots are reset to ObjectType{} but stay in objects_). A
  // search for a default-constructed object can therefore match a freed slot and return a handle to it. Callers must only search for
  // objects known to be alive
  HandleType findObject(const ObjectType* obj) {
    if (!obj)
      return {};

    for (IndexType idx = 0; idx != objects_.size(); idx++) {
      if (objects_[idx] == *obj) {
        return HandleType(idx, meta_[idx].gen_);
      }
    }

    return {};
  }
  void clear() {
    objects_.clear();
    meta_.clear();
    freeListHead_ = kListEndSentinel;
    numObjects_ = 0;
  }
  uint32_t numObjects() const {
    return numObjects_;
  }
};

} // namespace ldr
