/**
 * \file ptr.h
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

#pragma once

#include <cstddef>
#include <cstdint>

namespace ldr {

class IntrusiveCounter {
 public:
  virtual ~IntrusiveCounter() = default;
  void incRefCount();
  void decRefCount();
  uint32_t useCount() const {
    return refCounter_;
  }

  // NOTE: this is the price we pay for not using the <atomic> header
  static void incRef(void* p);
  static void decRef(void* p);

 private:
  volatile uint32_t refCounter_ = 0;
};

} // namespace ldr

template<class T>
class clPtr {
 public:
  clPtr() = default;
  clPtr(const clPtr& other) : value_(other.value_) {
    ldr::IntrusiveCounter::incRef(value_);
  }
  template<typename U>
  clPtr(const clPtr<U>& ptr) : value_(ptr.get()) {
    ldr::IntrusiveCounter::incRef(value_);
  }
  clPtr(T* const p) : value_(p) {
    ldr::IntrusiveCounter::incRef(value_);
  }
  clPtr(std::nullptr_t) : value_(nullptr) {}
  /// destructor
  ~clPtr() {
    ldr::IntrusiveCounter::decRef(value_);
  }
  clPtr& operator=(const clPtr& other) {
    T* temp = value_;
    value_ = other.value_;
    ldr::IntrusiveCounter::incRef(other.value_);
    ldr::IntrusiveCounter::decRef(temp);
    return *this;
  }
  inline T* operator->() const {
    return value_;
  }
  inline volatile T* operator->() const volatile {
    return value_;
  }
  explicit operator bool() const {
    return value_ != nullptr;
  } /// allow 'if (p)'
  template<typename U>
  inline clPtr<U> DynamicCast() const {
    return clPtr<U>(dynamic_cast<U*>(value_));
  }
  inline bool operator==(std::nullptr_t) const {
    return value_ == nullptr;
  }
  inline bool operator!=(std::nullptr_t) const {
    return value_ != nullptr;
  }
  template<typename U>
  inline bool operator==(const clPtr<U>& other) const {
    return value_ == other.get();
  }
  template<typename U>
  inline bool operator==(const U* other) const {
    return value_ == other;
  }
  template<typename U>
  inline bool operator!=(const clPtr<U>& other) const {
    return value_ != other.get();
  }
  template<typename U>
  inline bool operator<(const clPtr<U>& other) const {
    return value_ < other.get();
  }
  template<typename U>
  inline bool operator>(const clPtr<U>& other) const {
    return value_ > other.get();
  }
  inline T* get() const {
    return value_;
  }
  inline T* getPtr() const {
    return value_;
  }
  inline T& getRef() const {
    return *value_;
  }
  inline uint32_t useCount() const {
    return value_ ? value_->useCount() : 0;
  }
  inline bool isValid() const {
    return value_ != nullptr;
  }

 private:
  T* value_ = nullptr;
};
