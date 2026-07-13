/**
 * \file Span.h
 * \brief Lightweight non-owning view over a contiguous sequence
 *
 * \author Sergey Kosarevsky, 2026
 * \author sk@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <cstddef>
#include <initializer_list>

#include "Macros.h"

namespace ldr {

template<typename T>
class Span {
 public:
  Span() = default;
  Span(T* data, size_t numElements) : data_(data), numElements_(numElements) {}
  template<size_t N>
  Span(T (&arr)[N]) : data_(arr)
                    , numElements_(N) {}
  Span(std::initializer_list<T> list) : data_(const_cast<T*>(list.begin())), numElements_(list.size()) {}
  const T& operator[](size_t idx) const {
    return data_[idx];
  }
  T& operator[](size_t idx) {
    return data_[idx];
  }
  size_t size() const {
    return numElements_;
  }
  size_t size_bytes() const {
    return sizeof(T) * numElements_;
  }
  bool empty() const {
    return numElements_ == 0;
  }
  Span subspan(size_t offset, size_t count = 0) const {
    return Span(data_ + offset, count ? count : numElements_ - offset);
  }
  T* data() {
    return data_;
  }
  const T* data() const {
    return data_;
  }
  T* begin() {
    return data_;
  }
  const T* begin() const {
    return data_;
  }
  T* end() {
    return data_ + numElements_;
  }
  const T* end() const {
    return data_ + numElements_;
  }
  const T* cbegin() const {
    return data_;
  }
  const T* cend() const {
    return data_ + numElements_;
  }

 private:
  T* data_ = nullptr;
  size_t numElements_ = 0;
};

} // namespace ldr
