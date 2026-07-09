| Status | Feedback | Notes |
|---|---|---|
| ❌ | KPI box font size/style configurable? | |
| ❌ | Configurable notch shape/size | |
| ✅ | Reference arrow not to scale | PR #2: `add_scale_arrow!(ax, ::WaferArrows)` reads the plot's resolved scale |
| ✅ | Makie options not passable to plots | PR #2: recipes migrated to new `@recipe` DSL; kwargs now forward through |
| ✅ | NaN crashes | PR #2: `WaferData`/`WaferVectorData` filter non-finite rows at construction |
| ✅ | Boundary drawn twice on overlay | PR #2: `draw_wafer_boundary!`/`draw_fields!` now idempotent per-axis |
| ❌ | Heatmap interpolation bad at large sizes | Related index bug fixed in PR #2; not independently verified |
| ❌ | Donut plot (ring vs. inner, separate KPIs) | |
| ❌ | Metrics inside axis | |
| ❌ | Show KPI subset inside wafer plot | |
| ✅ | Dedicated AoG docs section | New `aog_compositing.md`: lot facets, heatmap+arrows, rings, KPI bars |
