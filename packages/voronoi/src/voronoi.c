//
// Диаграмма Вороного — алгоритм Форчуна (Fortune's sweep line).
//
// Заметающая прямая движется снизу вверх. На «пляжной линии» (beach line)
// хранятся дуги парабол — границы ячеек уже обработанных сайтов. Очередь
// событий (минимальная куча) содержит:
// • события сайта  — вставка новой точки-генератора;
// • круговые события — исчезновение средней дуги тройки соседей.
//
// Построение топологии рёбер выполняется через half-edges (полуребра с twin).
// Итоговая раскраска — отдельный проход: для каждого пикселя ищется ближайший
// сайт с ускорением через пространственное хеширование (bucket grid).

#include "voronoi.h"
#include <float.h>
#include <math.h>
#include <stdlib.h>

// Преобразует цвет из формата ARGB (0xAARRGGBB) в ABGR для Flutter/Skia.
static uint32_t argb_to_abgr_pixel(uint32_t argb) {
  uint32_t a = (argb >> 24) & 0xFFu;
  uint32_t r = (argb >> 16) & 0xFFu;
  uint32_t g = (argb >> 8) & 0xFFu;
  uint32_t b = argb & 0xFFu;
  return (r << 24) | (g << 16) | (b << 8) | a;
}

typedef struct vec2 {
  double x, y;
} vec2_t;

// Направленное ребро диаграммы: origin — вершина, twin — противоположное
// полуребро соседней ячейки, site_index — индекс «владельца» ячейки.
typedef struct half_edge {
  int origin_valid; // 1, если вершина уже зафиксирована круговым событием
  vec2_t origin;
  struct half_edge *twin;
  struct half_edge *next;
  struct half_edge *prev;
  int site_index;
} half_edge_t;

// Дуга пляжной линии: каждая дуга соответствует одному сайту и занимает
// горизонтальный интервал между точками излома с соседями.
typedef struct arc {
  int site_index;
  struct arc *prev;
  struct arc *next;
  struct event *circle_event; // запланированное исчезновение этой дуги
  half_edge_t *left_he;       // ребро слева от дуги (ещё строится)
  half_edge_t *right_he;      // ребро справа от дуги
} arc_t;

typedef enum { EVENT_SITE, EVENT_CIRCLE } event_type_t;

// Событие заметания: приоритет — меньший y, при равенстве — меньший x.
typedef struct event {
  event_type_t type;
  double y;
  double x;
  int site_index; // только для EVENT_SITE
  arc_t *arc;     // только для EVENT_CIRCLE — исчезающая дуга
  vec2_t circle_center;
  double circle_radius;
  int is_valid; // 0, если дуга изменилась до обработки события
} event_t;

// Минимальная бинарная куча событий.
typedef struct {
  event_t **data;
  size_t n;
  size_t cap;
} event_heap_t;

// Контекст одного прогона алгоритма Форчуна.
typedef struct {
  vec2_t *sites;
  size_t site_count;
  double width;
  double height;
  arc_t *beach; // голова двусвязного списка дуг пляжной линии
  event_heap_t heap;
  void **free_list; // все calloc/malloc — освобождаются разом в destroy
  size_t free_n;
  size_t free_cap;
} fortune_ctx_t;

// Обёртка над realloc: перевыделяет блок памяти заданного размера.
static void *xrealloc(void *p, size_t sz) {
  void *q = realloc(p, sz);
  return q;
}

// Добавляет указатель в список объектов, которые будут освобождены при
// уничтожении контекста.
static void register_free(fortune_ctx_t *ctx, void *p) {
  if (p == NULL) {
    return;
  }
  if (ctx->free_n >= ctx->free_cap) {
    size_t ncap = ctx->free_cap ? ctx->free_cap * 2 : 64;
    void **nq = xrealloc(ctx->free_list, ncap * sizeof *nq);
    if (!nq) {
      return;
    }
    ctx->free_list = nq;
    ctx->free_cap = ncap;
  }
  ctx->free_list[ctx->free_n++] = p;
}

// Освобождает всю память контекста алгоритма Форчуна и обнуляет его поля.
static void fortune_ctx_destroy(fortune_ctx_t *ctx) {
  for (size_t i = 0; i < ctx->free_n; i++) {
    free(ctx->free_list[i]);
  }
  free(ctx->free_list);
  free(ctx->heap.data);
  *ctx = (fortune_ctx_t){0};
}

// Возвращает 1, если событие a должно обрабатываться раньше b (меньше y, при
// равенстве — меньше x).
static int event_before(const event_t *a, const event_t *b) {
  if (a->y != b->y) {
    return a->y < b->y;
  }
  return a->x < b->x;
}

// Меняет местами два элемента в массиве кучи событий.
static void heap_swap(event_heap_t *h, size_t i, size_t j) {
  event_t *t = h->data[i];
  h->data[i] = h->data[j];
  h->data[j] = t;
}

// Поднимает элемент вверх по минимальной куче, восстанавливая порядок
// приоритетов.
static void heap_sift_up(event_heap_t *h, size_t i) {
  while (i > 0) {
    size_t p = (i - 1) / 2;
    if (!event_before(h->data[i], h->data[p])) {
      break;
    }
    heap_swap(h, i, p);
    i = p;
  }
}

// Опускает элемент вниз по минимальной куче, восстанавливая порядок
// приоритетов.
static void heap_sift_down(event_heap_t *h, size_t i) {
  for (;;) {
    size_t l = 2 * i + 1;
    size_t r = l + 1;
    size_t sm = i;
    if (l < h->n && event_before(h->data[l], h->data[sm])) {
      sm = l;
    }
    if (r < h->n && event_before(h->data[r], h->data[sm])) {
      sm = r;
    }
    if (sm == i) {
      break;
    }
    heap_swap(h, i, sm);
    i = sm;
  }
}

// Добавляет событие в минимальную кучу; возвращает 0 при ошибке выделения
// памяти.
static int heap_push(fortune_ctx_t *ctx, event_t *e) {
  event_heap_t *h = &ctx->heap;
  if (h->n >= h->cap) {
    size_t ncap = h->cap ? h->cap * 2 : 64;
    event_t **nq = xrealloc(h->data, ncap * sizeof *nq);
    if (!nq) {
      return 0;
    }
    h->data = nq;
    h->cap = ncap;
  }
  h->data[h->n++] = e;
  heap_sift_up(h, h->n - 1);
  return 1;
}

// Извлекает и возвращает событие с наивысшим приоритетом (минимальные y, затем
// x).
static event_t *heap_pop_min(fortune_ctx_t *ctx) {
  event_heap_t *h = &ctx->heap;
  if (h->n == 0) {
    return NULL;
  }
  event_t *root = h->data[0];
  h->data[0] = h->data[h->n - 1];
  h->n--;
  if (h->n > 0) {
    heap_sift_down(h, 0);
  }
  return root;
}

// Создаёт новое полуребро диаграммы Вороного, принадлежащее указанному сайту.
static half_edge_t *new_half_edge(fortune_ctx_t *ctx, int site_index) {
  half_edge_t *he = calloc(1, sizeof *he);
  if (!he) {
    return NULL;
  }
  he->site_index = site_index;
  he->origin_valid = 0;
  register_free(ctx, he);
  return he;
}

// Создаёт новую дугу пляжной линии, соответствующую указанному сайту.
static arc_t *new_arc(fortune_ctx_t *ctx, int site_index) {
  arc_t *a = calloc(1, sizeof *a);
  if (!a) {
    return NULL;
  }
  a->site_index = site_index;
  register_free(ctx, a);
  return a;
}

// Создаёт событие сайта — вставку новой точки при проходе заметающей прямой.
static event_t *new_event_site(fortune_ctx_t *ctx, double x, double y,
                               int site_index) {
  event_t *e = malloc(sizeof *e);
  if (!e) {
    return NULL;
  }
  *e = (event_t){0};
  e->type = EVENT_SITE;
  e->x = x;
  e->y = y;
  e->site_index = site_index;
  e->is_valid = 1;
  register_free(ctx, e);
  return e;
}

// Создаёт круговое событие — момент, когда дуга исчезает с пляжной линии.
static event_t *new_event_circle(fortune_ctx_t *ctx, double y, double x,
                                 arc_t *arc, vec2_t center, double radius) {
  event_t *e = malloc(sizeof *e);
  if (!e) {
    return NULL;
  }
  *e = (event_t){0};
  e->type = EVENT_CIRCLE;
  e->y = y;
  e->x = x;
  e->arc = arc;
  e->circle_center = center;
  e->circle_radius = radius;
  e->site_index = -1;
  e->is_valid = 1;
  register_free(ctx, e);
  return e;
}

// x-координата точки излома двух парабол с фокусами p и q при sweep_y.
// Парабола — множество точек, равноудалённых от сайта и от заметающей прямой.
// При равных y у обоих сайтов параболы вырождаются в вертикальные лучи.
static double parabola_intersect_x(vec2_t p, vec2_t q, double sweep_y) {
  // Оба сайта на текущей высоте заметания — делим интервал пополам.
  if (fabs(p.y - sweep_y) < 1e-10 && fabs(q.y - sweep_y) < 1e-10) {
    return (p.x + q.x) / 2.0;
  }
  // Один сайт на прямой — его парабола стала вертикальной линией x = site.x.
  if (fabs(p.y - sweep_y) < 1e-10) {
    return p.x;
  }
  if (fabs(q.y - sweep_y) < 1e-10) {
    return q.x;
  }

  // Решение квадратного уравнения пересечения двух парабол.
  double dp = 2.0 * (p.y - sweep_y);
  double dq = 2.0 * (q.y - sweep_y);

  double a = 1.0 / dp - 1.0 / dq;
  double b = -2.0 * p.x / dp + 2.0 * q.x / dq;
  double c = (p.x * p.x + p.y * p.y - sweep_y * sweep_y) / dp -
             (q.x * q.x + q.y * q.y - sweep_y * sweep_y) / dq;

  if (fabs(a) < 1e-10) {
    return -c / b;
  }

  double disc = b * b - 4.0 * a * c;
  double sqrt_disc = sqrt(fmax(0.0, disc));

  double x1 = (-b + sqrt_disc) / (2.0 * a);
  double x2 = (-b - sqrt_disc) / (2.0 * a);

  // Из двух корней берём тот, что лежит между параболами на пляжной линии:
  // для более низкого сайта (меньший y) — правый корень, иначе — левый.
  if (p.y < q.y) {
    return fmax(x1, x2);
  }
  return fmin(x1, x2);
}

// Возвращает x-координату точки излома между соседними дугами arc и arc->next.
static double breakpoint_x(const fortune_ctx_t *ctx, const arc_t *arc,
                           double sweep_y) {
  const vec2_t *p = &ctx->sites[arc->site_index];
  const vec2_t *q = &ctx->sites[arc->next->site_index];
  vec2_t pv = *p;
  vec2_t qv = *q;
  return parabola_intersect_x(pv, qv, sweep_y);
}

// Проверяет, попадает ли x-координата в горизонтальный интервал, занимаемый
// дугой.
static int arc_contains_x(const fortune_ctx_t *ctx, const arc_t *arc, double x,
                          double sweep_y) {
  // Крайние дуги списка неограничены с одной стороны.
  double left_x = -DBL_MAX;
  double right_x = DBL_MAX;
  if (arc->prev != NULL) {
    left_x = breakpoint_x(ctx, arc->prev, sweep_y);
  }
  if (arc->next != NULL) {
    right_x = breakpoint_x(ctx, arc, sweep_y);
  }
  return x >= left_x && x <= right_x;
}

// Вычисляет центр описанной окружности трёх точек; возвращает 0, если точки
// коллинеарны.
static int circumcenter(vec2_t a, vec2_t b, vec2_t c, vec2_t *out) {
  double d = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
  if (fabs(d) < 1e-10) {
    return 0;
  }
  double ux = ((a.x * a.x + a.y * a.y) * (b.y - c.y) +
               (b.x * b.x + b.y * b.y) * (c.y - a.y) +
               (c.x * c.x + c.y * c.y) * (a.y - b.y)) /
              d;
  double uy = ((a.x * a.x + a.y * a.y) * (c.x - b.x) +
               (b.x * b.x + b.y * b.y) * (a.x - c.x) +
               (c.x * c.x + c.y * c.y) * (b.x - a.x)) /
              d;
  out->x = ux;
  out->y = uy;
  return 1;
}

// Помечает круговое событие дуги как недействительное (дуга изменилась или
// удалена).
static void invalidate_circle_event(arc_t *arc) {
  if (arc != NULL && arc->circle_event != NULL) {
    arc->circle_event->is_valid = 0;
    arc->circle_event = NULL;
  }
}

// Заглушка для сохранения построенного ребра; в текущей реализации ничего не
// делает.
static void record_edge(fortune_ctx_t *ctx, half_edge_t *he) {
  (void)ctx;
  (void)he;
}

// Обрезает луч (origin + t*(dx,dy)) по границам прямоугольника
// [0,width]×[0,height].
static vec2_t clip_ray(double width, double height, vec2_t origin, double dx,
                       double dy) {
  double t = DBL_MAX;
  if (dx > 0) {
    t = fmin(t, (width - origin.x) / dx);
  }
  if (dx < 0) {
    t = fmin(t, -origin.x / dx);
  }
  if (dy > 0) {
    t = fmin(t, (height - origin.y) / dy);
  }
  if (dy < 0) {
    t = fmin(t, -origin.y / dy);
  }
  if (t == DBL_MAX) {
    t = 1000.0;
  }
  vec2_t end;
  end.x = origin.x + dx * t;
  end.y = origin.y + dy * t;
  return end;
}

// Завершает построение неограниченного ребра, обрезая его по границам холста.
static void finish_edge(fortune_ctx_t *ctx, half_edge_t *he) {
  if (he->origin_valid && he->twin && he->twin->origin_valid) {
    record_edge(ctx, he);
    return;
  }

  vec2_t s1 = ctx->sites[he->site_index];
  vec2_t s2 = ctx->sites[he->twin->site_index];

  // Биссектриса отрезка s1–s2 — направление неограниченного ребра Вороного.
  double mx = (s1.x + s2.x) / 2.0;
  double my = (s1.y + s2.y) / 2.0;
  double dx = -(s2.y - s1.y);
  double dy = s2.x - s1.x;
  vec2_t start;
  if (he->origin_valid) {
    start = he->origin;
  } else if (he->twin && he->twin->origin_valid) {
    start = he->twin->origin;
  } else {
    start.x = mx;
    start.y = my;
  }

  (void)clip_ray(ctx->width, ctx->height, start, dx, dy);
  record_edge(ctx, he);
}

// Завершает все оставшиеся незакрытые рёбра на пляжной линии после окончания
// заметания.
static void finish_edges(fortune_ctx_t *ctx) {
  arc_t *arc = ctx->beach;
  while (arc != NULL && arc->next != NULL) {
    half_edge_t *he = arc->right_he;
    if (he != NULL) {
      finish_edge(ctx, he);
    }
    arc = arc->next;
  }
}

// Три соседние дуги (a|b|c) могут сойтись в одной точке, когда описанная
// окружность трёх сайтов коснётся заметающей прямой снизу. Тогда средняя
// дуга b исчезает — планируем круговое событие.
static void check_circle_event(fortune_ctx_t *ctx, arc_t *arc) {
  if (arc->prev == NULL || arc->next == NULL) {
    return;
  }

  vec2_t a = ctx->sites[arc->prev->site_index];
  vec2_t b = ctx->sites[arc->site_index];
  vec2_t c = ctx->sites[arc->next->site_index];

  // Тройка должна быть по часовой стрелке (cross < 0), иначе дуга b
  // не схлопнется — описанная окружность лежит «не с той стороны».
  double cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  if (cross >= 0) {
    return;
  }
  vec2_t center;
  if (!circumcenter(a, b, c, &center)) {
    return;
  }

  double rdx = a.x - center.x;
  double rdy = a.y - center.y;
  double radius = sqrt(rdx * rdx + rdy * rdy);

  // Нижняя точка окружности — момент, когда дуга b покидает пляжную линию.
  double event_y = center.y + radius;

  event_t *ce = new_event_circle(ctx, event_y, center.x, arc, center, radius);
  if (!ce) {
    return;
  }
  arc->circle_event = ce;
  heap_push(ctx, ce);
}

// Событие сайта: новая точка разрезает существующую дугу на три части.
//
// Было:  ... — arc — ...
// Стало: ... — arc — new — arc2 — ...
// (старый сайт) (новый) (копия старого)
//
// Создаются два новых биссектрисных ребра (he1/he2) с парами twin.
static void handle_site_event(fortune_ctx_t *ctx, event_t *event) {
  int site_idx = event->site_index;

  if (ctx->beach == NULL) {
    ctx->beach = new_arc(ctx, site_idx);
    return;
  }

  // Найти дугу, над которой лежит новый сайт на текущей высоте заметания.
  arc_t *arc = ctx->beach;
  while (arc->next != NULL) {
    if (arc_contains_x(ctx, arc, event->x, event->y)) {
      break;
    }
    arc = arc->next;
  }

  // Старая дуга делится — её круговое событие больше не актуально.
  invalidate_circle_event(arc);

  arc_t *new_arc_node = new_arc(ctx, site_idx);
  arc_t *arc2 = new_arc(ctx, arc->site_index);
  if (!new_arc_node || !arc2) {
    free(arc2);
    free(new_arc_node);
    return;
  }

  // Вставка двух новых дуг в двусвязный список пляжной линии.
  arc2->next = arc->next;
  if (arc->next != NULL) {
    arc->next->prev = arc2;
  }
  arc2->prev = new_arc_node;
  new_arc_node->next = arc2;
  new_arc_node->prev = arc;
  arc->next = new_arc_node;

  // Пара полуребер на каждой из двух новых биссектрис.
  half_edge_t *he1 = new_half_edge(ctx, arc->site_index);
  half_edge_t *he1t = new_half_edge(ctx, site_idx);
  half_edge_t *he2 = new_half_edge(ctx, site_idx);
  half_edge_t *he2t = new_half_edge(ctx, arc->site_index);
  if (!he1 || !he1t || !he2 || !he2t) {
    free(he1);
    free(he1t);
    free(he2);
    free(he2t);
    free(new_arc_node);
    free(arc2);
    return;
  }

  he1->twin = he1t;
  he1t->twin = he1;
  he2->twin = he2t;
  he2t->twin = he2;

  arc->right_he = he1;
  new_arc_node->left_he = he1;
  new_arc_node->right_he = he2;
  arc2->left_he = he2;

  check_circle_event(ctx, arc);
  check_circle_event(ctx, arc2);
}

// Круговое событие: средняя дуга arc исчезает, соседи сливаются.
// Вершина диаграммы — центр описанной окружности. Между prev и next
// появляется новое ребро, проходящее через эту вершину.
static void handle_circle_event(fortune_ctx_t *ctx, event_t *event) {
  arc_t *arc = event->arc;
  vec2_t center = event->circle_center;

  vec2_t vertex;
  vertex.x = center.x;
  vertex.y = center.y;

  invalidate_circle_event(arc->prev);
  invalidate_circle_event(arc->next);

  // Зафиксировать вершину на рёбрах, которые сходились в этой точке.
  if (arc->left_he != NULL) {
    if (!arc->left_he->origin_valid) {
      arc->left_he->origin = vertex;
      arc->left_he->origin_valid = 1;
    }
    record_edge(ctx, arc->left_he);
  }
  if (arc->right_he != NULL && arc->right_he->twin != NULL) {
    half_edge_t *tw = arc->right_he->twin;
    if (!tw->origin_valid) {
      tw->origin = vertex;
      tw->origin_valid = 1;
    }
    record_edge(ctx, arc->right_he);
  }

  // Удалить среднюю дугу из списка (сама arc остаётся в free_list до destroy).
  if (arc->prev != NULL) {
    arc->prev->next = arc->next;
  }
  if (arc->next != NULL) {
    arc->next->prev = arc->prev;
  }
  if (ctx->beach == arc) {
    ctx->beach = arc->next;
  }

  arc_t *prev = arc->prev;
  arc_t *next = arc->next;
  if (prev == NULL || next == NULL) {
    return;
  }

  // Новое ребро между сайтами соседних дуг, проходящее через вершину.
  half_edge_t *he = new_half_edge(ctx, prev->site_index);
  half_edge_t *heT = new_half_edge(ctx, next->site_index);
  if (!he || !heT) {
    free(he);
    free(heT);
    return;
  }
  he->origin_valid = 1;
  he->origin = vertex;
  he->twin = heT;
  heT->twin = he;

  prev->right_he = he;
  next->left_he = he;

  check_circle_event(ctx, prev);
  check_circle_event(ctx, next);
}

// Запускает алгоритм Форчуна: строит диаграмму Вороного заметающей прямой.
static int fortune_run(fortune_ctx_t *ctx, const double *site_xs,
                       const double *site_ys, size_t site_count) {
  ctx->sites = malloc(site_count * sizeof(vec2_t));
  if (!ctx->sites) {
    return 0;
  }
  register_free(ctx, ctx->sites);

  for (size_t i = 0; i < site_count; i++) {
    ctx->sites[i].x = site_xs[i];
    ctx->sites[i].y = site_ys[i];
  }
  ctx->site_count = site_count;

  for (size_t i = 0; i < site_count; i++) {
    event_t *e = new_event_site(ctx, site_xs[i], site_ys[i], (int)i);
    if (!e || !heap_push(ctx, e)) {
      free(e);
      return 0;
    }
  }

  for (;;) {
    event_t *ev = NULL;

    // Пропускаем устаревшие круговые события (is_valid == 0).
    while ((ev = heap_pop_min(ctx)) != NULL) {
      if (ev->is_valid) {
        break;
      }
    }
    if (ev == NULL) {
      break;
    }
    if (ev->type == EVENT_SITE) {
      handle_site_event(ctx, ev);
    } else {
      handle_circle_event(ctx, ev);
    }
  }

  // Закрыть рёбра, оставшиеся незавершёнными на верхней границе заметания.
  finish_edges(ctx);
  return 1;
}

// Возвращает большее из двух целых чисел.
static int imax_int(int a, int b) { return a > b ? a : b; }

// Возвращает меньшее из двух целых чисел.
static int imin_int(int a, int b) { return a < b ? a : b; }

// Ускоренный поиск ближайшего сайта: сетка корзин фиксированного размера.
// Для пикселя обходим кольца вокруг его корзины, пока не найдём сайт
// ближе, чем расстояние до следующего кольца (ранний выход).
static int rasterise_bucket(const double *xs, const double *ys,
                            const uint32_t *colors, size_t n, uint32_t width,
                            uint32_t height, uint32_t *pixels) {
  double area = (double)width * (double)height;
  // Размер ячейки ~ половина среднего расстояния между сайтами.
  double bucket_size = fmax(1.0, sqrt(area / (double)n) * 0.5);
  int cols = imax_int(1, (int)ceil((double)width / bucket_size));
  int rows = imax_int(1, (int)ceil((double)height / bucket_size));

  int bucket_count = cols * rows;
  int *bucket_counts = calloc((size_t)bucket_count, sizeof *bucket_counts);
  if (!bucket_counts) {
    return 0;
  }

  // Первый проход: подсчёт сайтов в каждой корзине.
  for (size_t i = 0; i < n; i++) {
    int bx = imin_int(cols - 1, imax_int(0, (int)floor(xs[i] / bucket_size)));
    int by = imin_int(rows - 1, imax_int(0, (int)floor(ys[i] / bucket_size)));
    bucket_counts[by * cols + bx]++;
  }

  // Префиксные суммы → смещения для compact-массива индексов сайтов.
  int *bucket_offsets =
      malloc((size_t)(bucket_count + 1) * sizeof *bucket_offsets);

  if (!bucket_offsets) {
    free(bucket_counts);
    return 0;
  }

  bucket_offsets[0] = 0;
  for (int i = 0; i < bucket_count; i++) {
    bucket_offsets[i + 1] = bucket_offsets[i] + bucket_counts[i];
  }

  int total_slots = bucket_offsets[bucket_count];
  int *bucket_data = malloc((size_t)total_slots * sizeof *bucket_data);
  if (!bucket_data) {
    free(bucket_counts);
    free(bucket_offsets);
    return 0;
  }

  // Второй проход: раскладка индексов сайтов по корзинам.
  for (int i = 0; i < bucket_count; i++) {
    bucket_counts[i] = 0;
  }

  for (size_t i = 0; i < n; i++) {
    int bx = imin_int(cols - 1, imax_int(0, (int)floor(xs[i] / bucket_size)));
    int by = imin_int(rows - 1, imax_int(0, (int)floor(ys[i] / bucket_size)));
    int b = by * cols + bx;
    int off = bucket_offsets[b] + bucket_counts[b];
    bucket_data[off] = (int)i;
    bucket_counts[b]++;
  }

  for (uint32_t py = 0; py < height; py++) {
    for (uint32_t px = 0; px < width; px++) {
      int bx =
          imin_int(cols - 1, imax_int(0, (int)floor((double)px / bucket_size)));
      int by =
          imin_int(rows - 1, imax_int(0, (int)floor((double)py / bucket_size)));

      double best_dist = DBL_MAX;
      int best_idx = 0;

      // Поиск по расширяющимся кольцам корзин вокруг (bx, by).
      for (int ring = 0;; ring++) {
        int min_bx = imax_int(0, bx - ring);
        int max_bx = imin_int(cols - 1, bx + ring);
        int min_by = imax_int(0, by - ring);
        int max_by = imin_int(rows - 1, by + ring);

        for (int cby = min_by; cby <= max_by; cby++) {
          for (int cbx = min_bx; cbx <= max_bx; cbx++) {
            // На кольцах ring > 0 обходим только периметр, не внутренность.
            if (ring > 0 && cbx > min_bx && cbx < max_bx && cby > min_by &&
                cby < max_by) {
              continue;
            }

            int b = cby * cols + cbx;
            int start = bucket_offsets[b];
            int end = bucket_offsets[b + 1];

            for (int k = start; k < end; k++) {
              int i = bucket_data[k];
              double dx = (double)px - xs[i];
              double dy = (double)py - ys[i];
              double d = dx * dx + dy * dy;

              if (d < best_dist) {
                best_dist = d;
                best_idx = i;
              }
            }
          }
        }

        // Ближайший сайт не может быть дальше следующего кольца — выходим.
        if (best_dist < DBL_MAX) {
          double ring_dist = (double)(ring + 1) * bucket_size;
          if (best_dist <= ring_dist * ring_dist) {
            break;
          }
        }

        if (min_bx == 0 && max_bx == cols - 1 && min_by == 0 &&
            max_by == rows - 1) {
          break;
        }
      }

      pixels[py * width + px] = argb_to_abgr_pixel(colors[best_idx]);
    }
  }

  free(bucket_data);
  free(bucket_offsets);
  free(bucket_counts);
  return 1;
}

// Выделяет буфер пикселей заданного размера для результата растеризации.
static pixels_t *allocate_pixel_buffer(uint32_t width, uint32_t height) {
  pixels_t *p = malloc(sizeof *p);
  if (!p) {
    return NULL;
  }
  p->colors = malloc((size_t)width * (size_t)height * sizeof(uint32_t));
  if (!p->colors) {
    free(p);
    return NULL;
  }
  p->size = (size_t)width * (size_t)height;
  return p;
}

// Точка входа FFI: строит диаграмму Вороного алгоритмом Форчуна и раскрашивает
// холст.
FFI_PLUGIN_EXPORT pixels_t *
calculate_voronoi_fortune(uint32_t width, uint32_t height, double *points_x,
                          double *points_y, uint32_t *point_colors,
                          size_t points_count) {
  if (points_count == 0 || !points_x || !points_y || !point_colors) {
    return NULL;
  }

  pixels_t *out = allocate_pixel_buffer(width, height);
  if (!out) {
    return NULL;
  }

  fortune_ctx_t ctx = {0};
  ctx.width = (double)width;
  ctx.height = (double)height;

  // Топология рёбер (результат пока не используется при отрисовке).
  if (!fortune_run(&ctx, points_x, points_y, points_count)) {
    fortune_ctx_destroy(&ctx);
    free(out->colors);
    free(out);
    return NULL;
  }

  // Раскраска пикселей по ближайшему сайту (bucket grid).
  if (!rasterise_bucket(points_x, points_y, point_colors, points_count, width,
                        height, out->colors)) {
    fortune_ctx_destroy(&ctx);
    free(out->colors);
    free(out);
    return NULL;
  }

  fortune_ctx_destroy(&ctx);
  return out;
}

// Освобождает буфер пикселей, возвращённый calculate_voronoi_fortune.
FFI_PLUGIN_EXPORT void free_pixels(pixels_t *pixels) {
  if (pixels == NULL) {
    return;
  }
  free(pixels->colors);
  free(pixels);
}
