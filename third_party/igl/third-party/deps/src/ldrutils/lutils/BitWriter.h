/**
 * \file BitWriter.h
 * \brief
 *
 * Write bits to memory
 *
 * \version 1.0.0
 * \date 04/03/2023
 * \author Sergey Kosarevsky, 2023
 * \author support@linderdaum.com   http://www.linderdaum.com   http://blog.linderdaum.com
 * https://github.com/corporateshark/ldrutils
 */

#pragma once

#include <assert.h>

namespace ldr {

/// Write bits to memory assuming outBuf is preinitialized to all zeros
class BitWriter final {
 public:
  BitWriter(uint8_t* outBuf, uint32_t bufSizeBytes) : buf_(outBuf), bitCount_(bufSizeBytes << 3) {
    assert(outBuf);
    assert(bufSizeBytes);
  }

  // numBits - the number of bits to use from 'bits' (starting from the highest value bits)
  void writeBits(uint32_t bits, uint32_t numBits) {
    assert(bitPos_ + numBits <= bitCount_);
    while (numBits-- > 0) {
      buf_[bitPos_++ >> 3] |= ((bits >> numBits) & 1) << (7 - (bitPos_ & 7));
    }
  }

 private:
  uint8_t* buf_ = nullptr;
  uint64_t bitPos_ = 0;
  uint64_t bitCount_ = 0;
};

} // namespace ldr
