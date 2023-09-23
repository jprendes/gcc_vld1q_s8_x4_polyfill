#!/bin/bash

ROOT="$(dirname "$0")"
ARM_NEON_PATH="$(aarch64-linux-musl-gcc -x c -E <(echo '#include <arm_neon.h>') | grep -m1 "arm_neon.h" | sed -En 's|.*"(/usr/local/[^"]*/arm_neon.h)".*|\1|p')"
echo "ARM_NEON_PATH=$ARM_NEON_PATH"

function gen_polyfill_vld1q() {
    SHORT="$1"
    SIZE="${SHORT:1}"
    N=$(expr 128 / "${SIZE}")
    
    if [ "${SHORT:0:1}" == "s" ]; then
        TYPE="int"
    else
        TYPE="uint"
    fi

    cat <<EOF
#ifndef __POLYFILL_vld1q_${SHORT}_x4__
#define __POLYFILL_vld1q_${SHORT}_x4__

static inline ${TYPE}${SIZE}x${N}x4_t vld1q_${SHORT}_x4(const ${TYPE}${SIZE}_t *p)
{
    ${TYPE}${SIZE}x${N}x4_t ret;
    ret.val[0] = vld1q_${SHORT}(p + 0 * ${N});
    ret.val[1] = vld1q_${SHORT}(p + 1 * ${N});
    ret.val[2] = vld1q_${SHORT}(p + 2 * ${N});
    ret.val[3] = vld1q_${SHORT}(p + 3 * ${N});
    return ret;
}

#endif // __POLYFILL_vld1q_${SHORT}_x4__
EOF
}

function gen_polyfill_vst1q() {
    SHORT="$1"
    SIZE="${SHORT:1}"
    N=$(expr 128 / "${SIZE}")
    
    if [ "${SHORT:0:1}" == "s" ]; then
        TYPE="int"
    else
        TYPE="uint"
    fi

    cat <<EOF
#ifndef __POLYFILL_vst1q_${SHORT}_x4__
#define __POLYFILL_vst1q_${SHORT}_x4__

static inline void vst1q_${SHORT}_x4(${TYPE}${SIZE}_t *p, ${TYPE}${SIZE}x${N}x4_t a)
{
    vst1q_${SHORT}(p + 0 * ${N}, a.val[0]);
    vst1q_${SHORT}(p + 1 * ${N}, a.val[1]);
    vst1q_${SHORT}(p + 2 * ${N}, a.val[2]);
    vst1q_${SHORT}(p + 3 * ${N}, a.val[3]);
}

#endif // __POLYFILL_vst1q_${SHORT}_x4__
EOF
}

function gen_test_vld1q() {
    SHORT="$1"
    cat <<EOF
#include <arm_neon.h>
void test() { vld1q_${SHORT}_x4(0); }
EOF
}

function gen_test_vst1q() {
    SHORT="$1"
    SIZE="${SHORT:1}"
    N=$(expr 128 / "${SIZE}")
    
    if [ "${SHORT:0:1}" == "s" ]; then
        TYPE="int"
    else
        TYPE="uint"
    fi

    cat <<EOF
#include <arm_neon.h>
void test() { ${TYPE}${SIZE}x${N}x4_t x = {{0,0,0,0}}; vst1q_${SHORT}_x4(0, x); }
EOF
}

function test_vld1q() {
    SHORT="$1"
    aarch64-linux-musl-gcc -Werror=implicit-function-declaration -x c -c -o /dev/null <(gen_test_vld1q "$SHORT")
}

function test_vst1q() {
    SHORT="$1"
    aarch64-linux-musl-gcc -Werror=implicit-function-declaration -x c -c -o /dev/null <(gen_test_vst1q "$SHORT")
}

function polyfill_vld1q() {
    SHORT="$1"
    if ! test_vld1q "${SHORT}"; then
        echo "Polyfilling vld1q_${SHORT}_x4"
        gen_polyfill_vld1q "${SHORT}" >> $ARM_NEON_PATH
    fi
}

function polyfill_vst1q() {
    SHORT="$1"
    if ! test_vst1q "${SHORT}"; then
        echo "Polyfilling vst1q_${SHORT}_x4"
        gen_polyfill_vst1q "${SHORT}" >> $ARM_NEON_PATH
    fi
}

function polyfill_bits() {
    BITS="$1"
    polyfill_vld1q "s${BITS}"
    polyfill_vld1q "u${BITS}"
    polyfill_vst1q "s${BITS}"
    polyfill_vst1q "u${BITS}"
}

if command -v aarch64-linux-musl-gcc > /dev/null; then
    polyfill_bits 8
    polyfill_bits 16
    polyfill_bits 32
    polyfill_bits 64
fi