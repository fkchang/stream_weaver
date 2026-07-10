# Phase-1 dispatch benchmark

Rack end-to-end time is the in-process request duration; server time excludes Rack::Test response handling.

## ledger: create

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.072 | 0.160 | 0.072 | 0.160 | 140 | 0 | 0 | 1 | 7 / 356 | 1.00 |
| legacy_full | 3.463 | 8.082 | 3.464 | 8.083 | 75444 | 0 | 2 | 1 | 430 / 442 | 538.89 |
| named_full | 5.603 | 8.759 | 5.604 | 8.760 | 96075 | 0 | 1 | 1 | 430 / 442 | 686.25 |
| named_fragments | 7.309 | 16.644 | 7.310 | 16.645 | 99327 | 0 | 1 | 1 | 431 / 444 | 709.48 |
| update_filter | 7.304 | 15.314 | 7.306 | 15.316 | 99680 | 0 | 1 | 1 | 432 / 445 | 712.00 |

**FAIL** — `named_fragments` response 99327 B <= 1.20 × baseline 140 B (168.0 B).

**FAIL** — `update_filter` response 99680 B <= 1.20 × baseline 140 B (168.0 B).

## ledger: edit

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.074 | 0.099 | 0.074 | 0.099 | 147 | 0 | 0 | 1 | 7 / 356 | 1.00 |
| legacy_full | 5.166 | 7.880 | 5.168 | 7.881 | 74037 | 0 | 2 | 1 | 422 / 442 | 503.65 |
| named_full | 7.925 | 10.217 | 7.926 | 10.218 | 94271 | 0 | 1 | 1 | 422 / 442 | 641.30 |
| named_fragments | 9.109 | 13.200 | 9.110 | 13.202 | 95467 | 0 | 1 | 1 | 414 / 444 | 649.44 |
| update_filter | 9.437 | 11.729 | 9.438 | 11.730 | 95820 | 0 | 1 | 1 | 415 / 445 | 651.84 |

**FAIL** — `named_fragments` response 95467 B <= 1.20 × baseline 147 B (176.4 B).

**FAIL** — `update_filter` response 95820 B <= 1.20 × baseline 147 B (176.4 B).

## ledger: validation

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.068 | 0.075 | 0.068 | 0.075 | 100 | 0 | 0 | 1 | 4 / 356 | 1.00 |
| legacy_full | 5.987 | 10.311 | 5.987 | 10.313 | 74061 | 0 | 2 | 1 | 422 / 442 | 740.61 |
| named_full | 10.815 | 16.052 | 10.816 | 16.053 | 94295 | 0 | 1 | 1 | 422 / 442 | 942.95 |
| named_fragments | 9.625 | 13.420 | 9.625 | 13.420 | 2083 | 0 | 1 | 1 | 9 / 444 | 20.83 |
| update_filter | 10.424 | 15.887 | 10.425 | 15.888 | 2083 | 0 | 1 | 1 | 9 / 445 | 20.83 |

**FAIL** — `named_fragments` response 2083 B <= 1.20 × baseline 100 B (120.0 B).

**FAIL** — `update_filter` response 2083 B <= 1.20 × baseline 100 B (120.0 B).

## ledger: filter

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.093 | 0.137 | 0.093 | 0.137 | 175 | 15 | 0 | 1 | 8 / 356 | 1.00 |
| legacy_full | 5.587 | 8.797 | 5.588 | 8.798 | 8427 | 15 | 1 | 0 | 30 / 442 | 48.15 |
| named_full | 6.568 | 10.267 | 6.569 | 10.268 | 9110 | 15 | 1 | 0 | 30 / 442 | 52.06 |
| named_fragments | 6.447 | 9.268 | 6.448 | 9.269 | 9412 | 15 | 1 | 0 | 32 / 444 | 53.78 |
| update_filter | 7.679 | 15.253 | 7.681 | 15.253 | 9774 | 15 | 1 | 1 | 33 / 445 | 55.85 |

**FAIL** — `named_fragments` response 9412 B <= 1.20 × baseline 175 B (210.0 B).

**FAIL** — `update_filter` response 9774 B <= 1.20 × baseline 175 B (210.0 B).

## ledger: delete

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.064 | 0.068 | 0.064 | 0.069 | 0 | 0 | 0 | 1 | 0 / 356 | Inf |
| legacy_full | 9.806 | 13.792 | 9.808 | 13.793 | 72607 | 0 | 2 | 1 | 414 / 442 | Inf |
| named_full | 15.270 | 20.859 | 15.271 | 20.861 | 92447 | 0 | 1 | 1 | 414 / 442 | Inf |
| named_fragments | 15.908 | 23.024 | 15.910 | 23.026 | 93583 | 0 | 1 | 1 | 406 / 444 | Inf |
| update_filter | 17.374 | 26.321 | 17.375 | 26.322 | 93936 | 0 | 1 | 1 | 407 / 445 | Inf |

**FAIL** — `named_fragments` response 93583 B <= 1.20 × baseline 0 B (0.0 B).

**FAIL** — `update_filter` response 93936 B <= 1.20 × baseline 0 B (0.0 B).

## warroom: note_append

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.067 | 0.074 | 0.067 | 0.074 | 147 | 0 | 0 | 1 | 6 / 23 | 1.00 |
| legacy_full | 10.135 | 17.264 | 10.136 | 17.266 | 2549 | 0 | 2 | 1 | 26 / 45 | 17.34 |
| named_full | 14.052 | 19.983 | 14.053 | 19.985 | 2928 | 0 | 1 | 1 | 26 / 45 | 19.92 |
| named_fragments | 16.454 | 47.339 | 16.455 | 47.342 | 2635 | 0 | 1 | 1 | 10 / 47 | 17.93 |
| named_fragments_oob | 15.482 | 22.797 | 15.483 | 22.799 | 2654 | 0 | 1 | 1 | 10 / 47 | 18.05 |

**FAIL** — `named_fragments` response 2635 B <= 1.20 × baseline 147 B (176.4 B).

**FAIL** — `named_fragments_oob` response 2654 B <= 1.20 × baseline 147 B (176.4 B).

## warroom: column_move

| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| phlex_baseline | 0.075 | 0.082 | 0.075 | 0.082 | 370 | 0 | 0 | 1 | 12 / 23 | 1.00 |
| legacy_full | 11.041 | 16.529 | 11.041 | 16.530 | 2514 | 0 | 2 | 1 | 25 / 45 | 6.79 |
| named_full | 15.912 | 21.876 | 15.913 | 21.877 | 2893 | 0 | 1 | 1 | 25 / 45 | 7.82 |
| named_fragments | 17.256 | 23.950 | 17.258 | 23.952 | 2600 | 0 | 1 | 1 | 9 / 47 | 7.03 |
| named_fragments_oob | 18.317 | 28.865 | 18.318 | 28.866 | 3107 | 0 | 1 | 1 | 26 / 47 | 8.40 |

**FAIL** — `named_fragments` response 2600 B <= 1.20 × baseline 370 B (444.0 B).

**FAIL** — `named_fragments_oob` response 3107 B <= 1.20 × baseline 370 B (444.0 B).

