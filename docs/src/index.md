```@raw html
---
layout: home

hero:
  name: LithoWaferPlots.jl
  text: Wafer-map visualization for Julia
  tagline: Scatter, heatmaps, contours, CFD vector fields, faceting, exclusion rings, logos and KPIs for semiconductor wafer data — on any Makie backend.
  actions:
    - theme: brand
      text: Get Started
      link: /getting_started
    - theme: alt
      text: Gallery
      link: /gallery
    - theme: alt
      text: API Reference
      link: /api

features:
  - title: Seven plot recipes
    icon: 🗺️
    details: "Scatter, heatmap, contour, arrows, streamlines, divergence and vorticity — each draws the wafer boundary and V-notch automatically."
  - title: Fields, dies & faceting
    icon: 🔲
    details: "Overlay exposure-field and die boundaries on any plot; lay out multi-wafer grids with wafer_facet or AlgebraOfGraphics."
  - title: KPI panel
    icon: 📊
    details: "Built-in mean, σ, min/max, P99 and ±3σ metrics, extensible through a simple TypeContracts interface."
  - title: Annotations & branding
    icon: 🏷️
    details: "Edge-exclusion rings specified in mm-to-edge, plus custom logos and faded watermarks with full alpha support."
  - title: Fast time-to-first-plot
    icon: ⚡
    details: "A GPU image! texture path for dense heatmaps and a precompile workload that keeps the first plot well under a second."
  - title: Backend-agnostic
    icon: 🔌
    details: "CairoMakie, GLMakie and WGLMakie all work. Makie is a weak dependency, so the core package stays light."
  - title: Built from open references
    icon: 📖
    details: "Every part — geometry, SEMI conventions, algorithms — is derived from free, openly-licensed references. No proprietary, NDA-bound, or reverse-engineered material."
---
```

## Quick start

```julia
using LithoWaferPlots, CairoMakie   # or GLMakie / WGLMakie

wafer = WaferSpec(300.0)            # 300 mm wafer, notch at 270°
data  = WaferData(my_table, wafer)  # columns :x, :y (mm), :value

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma)
add_colorbar!(side, p; label = "Thickness (nm)")
add_kpi_panel!(side, data)
fig
```

![Wafer heatmap with exposure-field overlay](assets/example_heatmap_fields.png)

## Install

The package is not yet registered; install it (and its `TypeContracts` dependency) from GitHub:

```julia
using Pkg
Pkg.add(url = "https://github.com/el-oso/TypeContracts.jl")
Pkg.add(url = "https://github.com/el-oso/LithoWaferPlots.jl")
```

## Built entirely from open references

!!! tip "Open by construction"
    **Every part of LithoWaferPlots is derived from free, openly-licensed references** —
    wafer geometry, SEMI coordinate conventions, and the rendering algorithms alike.
    No proprietary, NDA-bound, or reverse-engineered material was used anywhere in this
    package. The complete provenance is below; each entry links to its public source.

| Source | License | Use |
|---|---|---|
| [cap1tan/wafermap](https://github.com/cap1tan/wafermap) | MIT | Notch geometry reference |
| [dougthor42/wafer_map](https://github.com/dougthor42/wafer_map) | MIT | SEMI wafer sizes |
| [xlhaw/wfmap](https://github.com/xlhaw/wfmap) | MIT | Heatmap binning reference |
| [Wikipedia: Substrate mapping](https://en.wikipedia.org/wiki/Substrate_mapping) | CC BY-SA | Domain overview |
| [Artwork Systems glossary](https://www.artwork.com/package/wmapconvert/manual_v2/glossary_of_terms.html) | Public | Notch/coordinate conventions |
| SEMI M20 / M21 (public descriptions) | Public | Coordinate & die addressing |
