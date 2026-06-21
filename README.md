# LithoWaferPlots.jl

[![CI](https://github.com/el-oso/LithoWaferPlots.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/el-oso/LithoWaferPlots.jl/actions/workflows/CI.yml)
[![Coverage](https://coveralls.io/repos/github/el-oso/LithoWaferPlots.jl/badge.svg?branch=master)](https://coveralls.io/github/el-oso/LithoWaferPlots.jl?branch=master)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Open-source semiconductor wafer map visualization for Julia.

![Heatmap with field overlay](docs/src/assets/example_heatmap_fields.png)

## Features

- **Seven plot types** — scatter, heatmap, contour, arrows, streamlines, divergence, vorticity
- **Field and die overlays** — rectangular exposure-field boundaries on any plot
- **KPI panel** — built-in metrics (mean, sigma, min, max, P99, ±3σ) with a clean extension contract
- **Any tabular input** — DataFrames, NamedTuples, CSV rows, or plain arrays via Tables.jl
- **mm and die-index coordinates** — automatic conversion from col/row to wafer mm
- **Fast rendering** — `image!` GPU texture path for dense heatmaps (>5K points); target 300K pts < 0.3 s on GLMakie
- **Backend-agnostic** — works with CairoMakie, GLMakie, and WGLMakie; Makie is a weak dependency

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/el-oso/LithoWaferPlots.jl")
Pkg.add("CairoMakie")   # or GLMakie / WGLMakie
```

## Quick start

```julia
using LithoWaferPlots
using CairoMakie          # any Makie backend

wafer = WaferSpec(300.0)  # 300 mm wafer, notch at bottom (270°)

# accepts any Tables.jl source: DataFrame, NamedTuple, CSV.File, …
data = WaferData((x=meas_x, y=meas_y, value=meas_v), wafer)

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap=:plasma)
add_colorbar!(side, p; label="Thickness (nm)")
add_kpi_panel!(side, data)
save("wafer.png", fig)
```

## Plot gallery

| Scatter | Heatmap | Contour |
|:---:|:---:|:---:|
| ![](docs/src/assets/example_scatter.png) | ![](docs/src/assets/example_heatmap.png) | ![](docs/src/assets/example_contour.png) |

| Arrows | Streamlines | Divergence | Vorticity |
|:---:|:---:|:---:|:---:|
| ![](docs/src/assets/example_arrows.png) | ![](docs/src/assets/example_streamlines.png) | ![](docs/src/assets/example_divergence.png) | ![](docs/src/assets/example_vorticity.png) |

## Die-index mode

```julia
grid = DieGrid(-75.0, -75.0, 5.0, 5.0)   # origin (mm from centre), die pitch (mm)
data = WaferData(df, grid, wafer)          # df has :col, :row, :value columns
```

## Field overlays

Pass a `fields` vector to draw exposure-field or die-boundary rectangles on any plot:

```julia
fw, fh, r = 26.0, 33.0, wafer.diameter_mm / 2.0
all_fields = vec([WaferField((ci - 0.5)*fw, (ri - 5)*fh, fw, fh, ci, ri)
                  for ri in 1:9, ci in -5:6])
# drop fields that lie entirely outside the wafer disk
fields = filter(all_fields) do f
    nx = clamp(0.0, f.x_center_mm - fw/2, f.x_center_mm + fw/2)
    ny = clamp(0.0, f.y_center_mm - fh/2, f.y_center_mm + fh/2)
    nx^2 + ny^2 <= r^2
end

data = WaferData(table, wafer; fields=fields)
p = waferheatmap!(ax, data; field_strokecolor=:black, field_strokewidth=1.5f0)
```

## Custom KPIs

```julia
struct MyRange <: AbstractKPI end
LithoWaferPlots.name(::MyRange)    = "Range"
LithoWaferPlots.compute(::MyRange, v) = maximum(v) - minimum(v)

add_kpi_panel!(side, data; kpis=[KPIMean(), KPISigma(), MyRange()])
```

## Vector fields

```julia
vdata = WaferVectorData((x=xs, y=ys, vx=vxs, vy=vys), wafer)

waferarrows!(ax, vdata; lengthscale=2.0)
waferstreamlines!(ax, vdata; n_seeds=12, max_steps=80)
waferdivergence!(ax, vdata; colormap=:RdBu)
wafervorticity!(ax, vdata)
```

## Running tests

```julia
julia --project=test test/runtests.jl
```

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgements

Built from free, open resources:
[cap1tan/wafermap](https://github.com/cap1tan/wafermap) (MIT) ·
[dougthor42/wafer_map](https://github.com/dougthor42/wafer_map) (MIT) ·
[xlhaw/wfmap](https://github.com/xlhaw/wfmap) (MIT) ·
[Wikipedia: Substrate mapping](https://en.wikipedia.org/wiki/Substrate_mapping) ·
SEMI M20/M21 coordinate conventions
