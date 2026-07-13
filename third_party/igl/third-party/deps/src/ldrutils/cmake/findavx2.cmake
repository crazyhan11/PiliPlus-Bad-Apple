macro(LMATH_CHECK_FOR_AVX2)
	include(CheckCXXSourceRuns)

	set(CMAKE_REQUIRED_FLAGS)

	if(MSVC)
		set(CMAKE_REQUIRED_FLAGS "/arch:AVX")
	else()
		set(CMAKE_REQUIRED_FLAGS "-mavx")
	endif()

	check_cxx_source_runs("
		#include <immintrin.h>
		int main() {
			const float src[8] = { 0.0f, 1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f };
			float dst[8];
			_mm256_storeu_ps(dst, _mm256_add_ps(_mm256_loadu_ps(src), _mm256_loadu_ps(src)));
			for (size_t i = 0; i != 8; i++)
				if ((src[i]+src[i]) != dst[i]) return -1;
			return 0;
		}"
		HAVE_AVX)

	if(MSVC)
		set(CMAKE_REQUIRED_FLAGS "/arch:AVX2")
	else()
		set(CMAKE_REQUIRED_FLAGS "-mavx2")
	endif()

	check_cxx_source_runs("
		#include <immintrin.h>
		int main() {
			const int src[8] = { 0, 1, 2, 3, 4, 5, 6, 7 };
			int dst[8];
			_mm256_storeu_si256((__m256i*)dst, _mm256_add_epi32(_mm256_loadu_si256((__m256i*)src), _mm256_loadu_si256((__m256i*)src)));
			for (size_t i = 0; i != 8; i++)
				if ((src[i]+src[i]) != dst[i]) return -1;
			return 0;
		}"
		HAVE_AVX2)

	set(CMAKE_REQUIRED_FLAGS)
endmacro()
