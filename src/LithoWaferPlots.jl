"""
    LithoWaferPlots

Open-source semiconductor wafer map visualization for Julia.

## Free sources used (IP hygiene)
- cap1tan/wafermap (MIT): https://github.com/cap1tan/wafermap
- dougthor42/wafer_map (MIT): https://github.com/dougthor42/wafer_map
- xlhaw/wfmap (MIT): https://github.com/xlhaw/wfmap
- Wikipedia: Substrate mapping: https://en.wikipedia.org/wiki/Substrate_mapping
- Artwork Systems glossary: https://www.artwork.com/package/wmapconvert/manual_v2/glossary_of_terms.html
- SEMI M20 (public description): wafer coordinate system
- SEMI M21 (public description): die Cartesian addressing

## Coordinate convention (SEMI M20)
Origin at wafer centre. Units: mm. +x right, +y up.
Notch at 270° = bottom (6 o'clock position).
"""
module LithoWaferPlots

using Statistics: mean, std, median, quantile
using NearestNeighbors: KDTree, knn, knn!
using Random: randperm
using Tables
using TypeContracts

include("types.jl")
include("geometry.jl")
include("input.jl")
include("contracts.jl")
include("kpi.jl")
include("colorscale.jl")
include("vectorfields.jl")
include("plot_interface.jl")

export WaferSpec, DieGrid, WaferField, WaferDie, WaferData, WaferVectorData
export wafer_polygon, inside_wafer, field_bounds, die_bounds
export AbstractKPI, DEFAULT_KPIS, name, compute, format_value
export KPIMean, KPISigma, KPIMax, KPIMin, KPIMedian,
    KPIMeanPlus3Sigma, KPIMeanMinus3Sigma, KPIP99
export ColorScale, normalize
export divergence, vorticity
# plotting stubs (implementations in Makie extension)
export wafer_figure, wafer_cfd_figure, wafer_facet, add_colorbar!, add_kpi_panel!
export add_exclusion_ring!, add_ring_legend!
export add_image_overlay!, add_logo!, add_watermark!
export waferscatter, waferscatter!
export waferheatmap, waferheatmap!
export wafercontour, wafercontour!
export waferarrows, waferarrows!
export waferstreamlines, waferstreamlines!
export waferdivergence, waferdivergence!
export wafervorticity, wafervorticity!

end
