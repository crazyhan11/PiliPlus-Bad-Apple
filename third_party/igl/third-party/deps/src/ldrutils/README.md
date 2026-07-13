# Building

Requires CMake 3.22+ and a C++20 compiler.

```
cmake -B build -DLMATH_ENABLE_TESTS=ON
cmake --build build
```

## CMake options

| Option | Default | Description |
|--------|---------|-------------|
| `LMATH_ENABLE_TESTS` | `OFF` | Build tests (Google Test) |
| `LMATH_ENABLE_AVX` | `ON` | Enable AVX (auto-disabled if unsupported) |
| `LMATH_ENABLE_AVX2` | `ON` | Enable AVX2 (auto-disabled if unsupported) |
| `LMATH_USE_SHORTCUT_TYPES` | `OFF` | Use lmath types without the `ldr::` namespace |

# lutils

 `Array2D.h` - A simple 2D array on top of a 1D vector container (std::vector etc).

 `BitWriter.h` - Write individual bits to memory.

 `CVar.h` - OLEVariant-like untyped variable.

 `DynamicLibrary.h` - Cross-platform dynamic link libraries (.dll/.so).

 `Handle.h` - Lightweight non-ref-counted generational handles.

 `Macros.h` - Useful utility macros.

 `Ptr.h` - Minimalistic intrusive smartpointer.

 `Pool.h` - Generational object pool with free-list slot recycling, accessed through `Handle<>`.

 `PtrUtils.h` - Intrusive smartpointer utils (depends on the <utility> header).

 `ScopeExit.h` - RAII scope guard macro.

 `Utils.h` - Various utility functions.

# lmath

 `Blending.h` - Bitmap blending operators.

 `Colors.h` - Predefined color constants.

 `Geometry.h` - Geometry utilities.

 `GeometryShapes.h` - Mesh generation (quad, disk, icosphere, box, etc).

 `Math.h` - Math utilities.

 `Matrix.h` - mat3/mat4.

 `Plane.h` - plane3.

 `Ray.h` - ray3.

 `Vector.h` - vec2/vec3/vec4.
