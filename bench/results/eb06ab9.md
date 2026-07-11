# Phase-1 dispatch benchmark

Rack end-to-end time is the in-process request duration; server time excludes Rack::Test response handling.

## ledger: create

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.077 | 0.141 | 0.077 | 0.142 | 140 | 0 | 0 | 1 | 7 / 356 | 1.00 |
| legacy_full | 3.287 | 9.863 | 3.288 | 9.864 | 72463 | 0 | 2 | 1 | 430 / 442 | 517.59 |
| named_full | 4.837 | 7.102 | 4.838 | 7.102 | 93094 | 0 | 1 | 1 | 430 / 442 | 664.96 |
| named_fragments | 3.795 | 5.566 | 3.795 | 5.568 | 3945 | 0 | 1 | 1 | 17 / 444 | 28.18 |
| update_filter | 4.274 | 6.624 | 4.275 | 6.624 | 3945 | 0 | 1 | 1 | 17 / 445 | 28.18 |

**PASS** — `named_fragments` response 3945 B <= 1.20 × baseline 140 B (168.0 B) or <= 8192 B floor.

**PASS** — `update_filter` response 3945 B <= 1.20 × baseline 140 B (168.0 B) or <= 8192 B floor.

## ledger: edit

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.074 | 0.109 | 0.075 | 0.110 | 147 | 0 | 0 | 1 | 7 / 356 | 1.00 |
| legacy_full | 4.771 | 7.026 | 4.772 | 7.027 | 71107 | 0 | 2 | 1 | 422 / 442 | 483.72 |
| named_full | 7.445 | 10.962 | 7.446 | 10.963 | 91341 | 0 | 1 | 1 | 422 / 442 | 621.37 |
| named_fragments | 6.711 | 10.778 | 6.711 | 10.778 | 1999 | 0 | 1 | 1 | 9 / 444 | 13.60 |
| update_filter | 7.403 | 10.551 | 7.404 | 10.552 | 1999 | 0 | 1 | 1 | 9 / 445 | 13.60 |

**PASS** — `named_fragments` response 1999 B <= 1.20 × baseline 147 B (176.4 B) or <= 8192 B floor.

**PASS** — `update_filter` response 1999 B <= 1.20 × baseline 147 B (176.4 B) or <= 8192 B floor.

## ledger: validation

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.070 | 0.096 | 0.070 | 0.096 | 100 | 0 | 0 | 1 | 4 / 356 | 1.00 |
| legacy_full | 5.332 | 8.063 | 5.332 | 8.065 | 71135 | 0 | 2 | 1 | 422 / 442 | 711.35 |
| named_full | 9.938 | 16.164 | 9.939 | 16.166 | 91369 | 0 | 1 | 1 | 422 / 442 | 913.69 |
| named_fragments | 10.268 | 16.219 | 10.269 | 16.220 | 2100 | 0 | 1 | 1 | 9 / 444 | 21.00 |
| update_filter | 12.519 | 20.038 | 12.520 | 20.040 | 2100 | 0 | 1 | 1 | 9 / 445 | 21.00 |

**PASS** — `named_fragments` response 2100 B <= 1.20 × baseline 100 B (120.0 B) or <= 8192 B floor.

**PASS** — `update_filter` response 2100 B <= 1.20 × baseline 100 B (120.0 B) or <= 8192 B floor.

## ledger: filter

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.094 | 0.223 | 0.094 | 0.223 | 175 | 15 | 0 | 1 | 8 / 356 | 1.00 |
| legacy_full | 5.048 | 10.228 | 5.049 | 10.230 | 4284 | 15 | 1 | 0 | 30 / 442 | 24.48 |
| named_full | 5.947 | 9.940 | 5.947 | 9.941 | 4967 | 15 | 1 | 0 | 30 / 442 | 28.38 |
| named_fragments | 6.432 | 10.047 | 6.433 | 10.047 | 5289 | 15 | 1 | 0 | 32 / 444 | 30.22 |
| update_filter | 6.812 | 12.296 | 6.814 | 12.298 | 5651 | 15 | 1 | 1 | 33 / 445 | 32.29 |

**PASS** — `named_fragments` response 5289 B <= 1.20 × baseline 175 B (210.0 B) or <= 8192 B floor.

**PASS** — `update_filter` response 5651 B <= 1.20 × baseline 175 B (210.0 B) or <= 8192 B floor.

## ledger: delete

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.072 | 0.114 | 0.072 | 0.115 | 0 | 0 | 0 | 1 | 0 / 356 | Inf |
| legacy_full | 9.727 | 16.812 | 9.729 | 16.814 | 69740 | 0 | 2 | 1 | 414 / 442 | Inf |
| named_full | 17.151 | 21.766 | 17.152 | 21.768 | 89580 | 0 | 1 | 1 | 414 / 442 | Inf |
| named_fragments | 16.349 | 21.140 | 16.351 | 21.141 | 172 | 0 | 1 | 1 | 1 / 444 | Inf |
| update_filter | 14.547 | 19.288 | 14.548 | 19.289 | 172 | 0 | 1 | 1 | 1 / 445 | Inf |

**PASS** — `named_fragments` response 172 B <= 1.20 × baseline 0 B (0.0 B) or <= 8192 B floor.

**PASS** — `update_filter` response 172 B <= 1.20 × baseline 0 B (0.0 B) or <= 8192 B floor.

## warroom: note_append

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.068 | 0.138 | 0.068 | 0.138 | 147 | 0 | 0 | 1 | 6 / 23 | 1.00 |
| legacy_full | 9.103 | 14.929 | 9.103 | 14.931 | 1723 | 0 | 2 | 1 | 26 / 45 | 11.72 |
| named_full | 14.339 | 18.781 | 14.340 | 18.782 | 2102 | 0 | 1 | 1 | 26 / 45 | 14.30 |
| named_fragments | 16.124 | 22.015 | 16.126 | 22.016 | 1795 | 0 | 1 | 1 | 10 / 47 | 12.21 |
| named_fragments_oob | 16.704 | 25.253 | 16.705 | 25.255 | 1814 | 0 | 1 | 1 | 10 / 47 | 12.34 |

**PASS** — `named_fragments` response 1795 B <= 1.20 × baseline 147 B (176.4 B) or <= 8192 B floor.

**PASS** — `named_fragments_oob` response 1814 B <= 1.20 × baseline 147 B (176.4 B) or <= 8192 B floor.

## warroom: column_move

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.077 | 0.163 | 0.077 | 0.164 | 370 | 0 | 0 | 1 | 12 / 23 | 1.00 |
| legacy_full | 10.802 | 17.991 | 10.804 | 17.993 | 1703 | 0 | 2 | 1 | 25 / 45 | 4.60 |
| named_full | 16.677 | 22.323 | 16.679 | 22.324 | 2082 | 0 | 1 | 1 | 25 / 45 | 5.63 |
| named_fragments | 17.006 | 24.690 | 17.006 | 24.692 | 1775 | 0 | 1 | 1 | 9 / 47 | 4.80 |
| named_fragments_oob | 18.229 | 26.563 | 18.231 | 26.564 | 2282 | 0 | 1 | 1 | 26 / 47 | 6.17 |

**PASS** — `named_fragments` response 1775 B <= 1.20 × baseline 370 B (444.0 B) or <= 8192 B floor.

**PASS** — `named_fragments_oob` response 2282 B <= 1.20 × baseline 370 B (444.0 B) or <= 8192 B floor.

