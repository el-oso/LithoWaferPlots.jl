module LithoWaferPlotsMakieExt

using Makie
using LithoWaferPlots
using LithoWaferPlots: WaferSpec, WaferData, WaferVectorData, WaferField,
    wafer_polygon, inside_wafer, field_bounds,
    ColorScale, normalize, DEFAULT_KPIS, AbstractKPI,
    name, compute, format_value,
    divergence, vorticity
using NearestNeighbors: KDTree, knn
using Random: randperm

include("wafer_shape.jl")
include("streamlines.jl")
include("layout.jl")
include("recipes_scalar.jl")
include("recipes_vector.jl")

export wafer_figure, wafer_cfd_figure, add_colorbar!, add_kpi_panel!
export add_exclusion_ring!, add_ring_legend!
export WaferScatter, waferscatter, waferscatter!
export WaferHeatmap, waferheatmap, waferheatmap!
export WaferContour, wafercontour, wafercontour!
export WaferArrows, waferarrows, waferarrows!
export WaferStreamlines, waferstreamlines, waferstreamlines!
export WaferDivergence, waferdivergence, waferdivergence!
export WaferVorticity, wafervorticity, wafervorticity!

end
