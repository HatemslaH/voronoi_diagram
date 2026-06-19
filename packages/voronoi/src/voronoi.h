#ifndef VORONOI_H
#define VORONOI_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

/* Буфер раскрашенных пикселей, возвращаемый нативной библиотекой. */
typedef struct {
  uint32_t *colors;
  size_t size;
} pixels_t;

/* Строит диаграмму Вороного алгоритмом Форчуна и возвращает раскрашенный буфер пикселей. */
FFI_PLUGIN_EXPORT pixels_t *
calculate_voronoi_fortune(uint32_t width, uint32_t height, double *points_x,
                          double *points_y, uint32_t *point_colors,
                          size_t points_count);

/* Освобождает память, выделенную для буфера пикселей. */
FFI_PLUGIN_EXPORT void free_pixels(pixels_t *pixels);

#endif
