#ifndef DJMEMORY_ATOMICS_H
#define DJMEMORY_ATOMICS_H

#include <stdint.h>

/// Minimal lock-free 64-bit atomics for the real-time audio ring.
///
/// The deployment target is macOS 14, so `Synchronization.Atomic` (macOS 15+) is not
/// available, and `OSAtomic*` is deprecated and cannot be applied safely to Swift stored
/// properties — taking `&property` as `inout` does not guarantee a stable address, so the
/// operation is not reliably atomic. These operate on a caller-owned, heap-allocated
/// `int64_t` whose address never moves. Header-only, platform SDK only, no dependencies.

static inline int64_t djm_atomic_load_acquire(const int64_t *p) {
    return __atomic_load_n(p, __ATOMIC_ACQUIRE);
}

static inline int64_t djm_atomic_load_relaxed(const int64_t *p) {
    return __atomic_load_n(p, __ATOMIC_RELAXED);
}

static inline void djm_atomic_store_release(int64_t *p, int64_t value) {
    __atomic_store_n(p, value, __ATOMIC_RELEASE);
}

static inline void djm_atomic_store_relaxed(int64_t *p, int64_t value) {
    __atomic_store_n(p, value, __ATOMIC_RELAXED);
}

static inline void djm_atomic_add_relaxed(int64_t *p, int64_t value) {
    (void)__atomic_fetch_add(p, value, __ATOMIC_RELAXED);
}

#endif /* DJMEMORY_ATOMICS_H */
