| Status | Feedback | Notes |
|---|---|---|
| ✅ | KPI box font size/style configurable? | `add_kpi_panel!(...; title, fontsize, font, title_fontsize)` |
| ✅ | Configurable notch shape/size | `WaferSpec(...; notch_shape=:rounded_u\|:flat\|:v, notch_width_mm=...)`; width decoupled from depth |
| ✅ | Reference arrow not to scale | PR #2: `add_scale_arrow!(ax, ::WaferArrows)` reads the plot's resolved scale |
| ✅ | Makie options not passable to plots | PR #2: recipes migrated to new `@recipe` DSL; kwargs now forward through |
| ✅ | NaN crashes | PR #2: `WaferData`/`WaferVectorData` filter non-finite rows at construction |
| ✅ | Boundary drawn twice on overlay | PR #2: `draw_wafer_boundary!`/`draw_fields!` now idempotent per-axis |
| ❌ | Heatmap interpolation bad at large sizes | Related index bug fixed in PR #2; not independently verified |
| ✅ | Donut plot (ring vs. inner, separate KPIs) | New `zone_kpis`/`add_zone_kpis!(ax, data; mm_to_edge=...)`: radial inner/ring split with separate KPI overlays |
| ✅ | Metrics inside axis | New `add_kpi_overlay!(ax, data; position=...)`: corner-anchored KPI box drawn on the plot itself |
| ✅ | Show KPI subset inside wafer plot | `add_kpi_overlay!`'s `kpis=` accepts any subset (same mechanism `add_kpi_panel!` already had) |
| ✅ | Dedicated AoG docs section | New `aog_compositing.md`: lot facets, heatmap+arrows, rings, KPI bars |
