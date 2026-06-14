# LithoWaferPlots.jl

Open-source semiconductor wafer map visualization for Julia.

![Heatmap with field overlay](assets/example_heatmap_fields.png)

## Quick start

```julia
using LithoWaferPlots
using GLMakie

wafer = WaferSpec(300.0)   # 300mm wafer, notch at bottom

# x, y in mm from wafer centre; value is your measurement
data = WaferData(my_table, wafer)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data)
add_colorbar!(side, p; label="Thickness (nm)")
add_kpi_panel!(side, data)
display(fig)
```

## Features

- **Heatmap, scatter, contour** plots on circular wafer geometry
- **Vector field** plots: arrows, streamlines, divergence, vorticity
- **Field and die overlays** via `WaferField`
- **KPI panel** with built-in and user-defined metrics
- **300 000 points in < 0.3 s** (GLMakie GPU path)
- **Any tabular input** — DataFrames, NamedTuples, CSV rows via Tables.jl
- **Both mm and die-index coordinates**

## Sources

This package is built entirely from free, open resources:

| Source | License | Use |
|---|---|---|
| [cap1tan/wafermap](https://github.com/cap1tan/wafermap) | MIT | Notch geometry reference |
| [dougthor42/wafer_map](https://github.com/dougthor42/wafer_map) | MIT | SEMI wafer sizes |
| [xlhaw/wfmap](https://github.com/xlhaw/wfmap) | MIT | Heatmap binning reference |
| [Wikipedia: Substrate mapping](https://en.wikipedia.org/wiki/Substrate_mapping) | CC BY-SA | Domain overview |
| [Artwork Systems glossary](https://www.artwork.com/package/wmapconvert/manual_v2/glossary_of_terms.html) | Public | Notch/coordinate conventions |
| SEMI M20 / M21 (public descriptions) | Public | Coordinate & die addressing |
