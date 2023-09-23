# Polyfill for missing SIMD intrinsics in `cross-rs` image for target `aarch64-unknown-linux-musl`

If you are building your project using `cross-rs` and some `c/c++` dependency fails to compile complaining about missing symbols `vld1q_s8_x4` or `vld1q_u8_x4`, this is for you.

The `vld1q_s8_x4` and `vld1q_u8_x4` function are compiler built-in SIMD intrinsics.
These intrinsics are missing for `aarch64` in `gcc < 10.3`, while `cross-rs` ships with `gcc 9` for `aarch64-unknown-linux-musl` as of writing.

The code in this repo does a feature check and patches the `arm_neon.h` header with polyfills if the functions are missing.
It becomes a no-op if the compiler has these functions.

To use in your `Dockerfile` just add the following line:
```Dockerfile
RUN --mount=type=bind,from=jorgeprendes420/gcc_vld1q_s8_x4_polyfill,target=/polyfill /polyfill/polyfill.sh
```
