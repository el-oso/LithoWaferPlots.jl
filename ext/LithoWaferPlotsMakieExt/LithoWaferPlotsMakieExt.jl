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
using Tables

include("wafer_shape.jl")
include("streamlines.jl")
include("layout.jl")
include("recipes_scalar.jl")
include("recipes_vector.jl")

export wafer_figure, wafer_cfd_figure, wafer_facet, add_colorbar!, add_kpi_panel!
export add_exclusion_ring!, add_ring_legend!
export WaferScatter, waferscatter, waferscatter!
export WaferHeatmap, waferheatmap, waferheatmap!
export WaferContour, wafercontour, wafercontour!
export WaferArrows, waferarrows, waferarrows!
export WaferStreamlines, waferstreamlines, waferstreamlines!
export WaferDivergence, waferdivergence, waferdivergence!
export WaferVorticity, wafervorticity, wafervorticity!

# Precompile workload: runs only during Pkg.precompile(), caching the compiled
# recipe methods so time-to-first-plot drops from ~10 s to < 0.5 s.
if ccall(:jl_generating_output, Cint, ()) == 1
    let wafer = WaferSpec(300.0),
            x = Float64[-80.0, 0.0, 80.0],
            y = Float64[-80.0, 0.0, 80.0],
            v = Float64[1.0, 2.0, 3.0]

        sdata = WaferData((x = x, y = y, value = v), wafer)

        fig, ax, side = wafer_figure()
        p = waferheatmap!(ax, sdata)
        add_colorbar!(side, p; label = "test")
        add_kpi_panel!(side, sdata)

        fig2, ax2, side2 = wafer_figure()
        p2 = waferscatter!(ax2, sdata)
        add_colorbar!(side2, p2)
    end
end

end
