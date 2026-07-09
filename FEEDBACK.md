| Status | Feedback | Notes |
|---|---|---|
| Open | KPI box font size/style configurable? | |
| Open | Configurable notch shape/size | |
| Done | Reference arrow not to scale | PR #2: `add_scale_arrow!(ax, ::WaferArrows)` reads the plot's resolved scale |
| Done | Makie options not passable to plots | PR #2: recipes migrated to new `@recipe` DSL; kwargs now forward through |
| Done | NaN crashes | PR #2: `WaferData`/`WaferVectorData` filter non-finite rows at construction |
| Done | Boundary drawn twice on overlay | PR #2: `draw_wafer_boundary!`/`draw_fields!` now idempotent per-axis |
| Open | Heatmap interpolation bad at large sizes | Related index bug fixed in PR #2; not independently verified |
| Open | Donut plot (ring vs. inner, separate KPIs) | |
| Open | Metrics inside axis | |
| Open | Show KPI subset inside wafer plot | |
| Done | Dedicated AoG docs section | New `aog_compositing.md`: lot facets, heatmap+arrows, rings, KPI bars |
