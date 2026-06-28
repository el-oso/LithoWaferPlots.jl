module LithoWaferPlotsMakieExt

using Makie
using LithoWaferPlots
using LithoWaferPlots: WaferSpec, WaferData, WaferVectorData, WaferField,
    wafer_polygon, inside_wafer, field_bounds,
    ColorScale, normalize, DEFAULT_KPIS, AbstractKPI,
    name, compute, format_value,
    divergence, vorticity, _vector_to_grid
using NearestNeighbors: KDTree, knn, knn!
using Random: randperm
using Tables

include("wafer_shape.jl")
include("streamlines.jl")
include("layout.jl")
include("overlay.jl")
include("recipes_scalar.jl")
include("recipes_vector.jl")

export wafer_figure, wafer_cfd_figure, wafer_facet, add_colorbar!, add_kpi_panel!
export add_exclusion_ring!, add_ring_legend!
export add_image_overlay!, add_logo!, add_watermark!, add_scale_arrow!
export WaferScatter, waferscatter, waferscatter!
export WaferHeatmap, waferheatmap, waferheatmap!
export WaferContour, wafercontour, wafercontour!
export WaferArrows, waferarrows, waferarrows!
export WaferStreamlines, waferstreamlines, waferstreamlines!
export WaferDivergence, waferdivergence, waferdivergence!
export WaferVorticity, wafervorticity, wafervorticity!

# Precompile workload: runs only during Pkg.precompile(), caching the compiled recipe
# methods so the first plot in a session is fast. Covers every recipe + the layout,
# annotation and overlay helpers so no public plotting path compiles on first use.
if ccall(:jl_generating_output, Cint, ()) == 1
    let wafer = WaferSpec(300.0),
            x = Float64[-80.0, 0.0, 80.0, 40.0, -40.0],
            y = Float64[-80.0, 0.0, 80.0, -40.0, 40.0],
            v = Float64[1.0, 2.0, 3.0, 2.0, 1.0],
            vx = Float64[0.1, -0.2, 0.3, -0.1, 0.2],
            vy = Float64[0.2, 0.1, -0.3, 0.2, -0.1]

        sdata = WaferData((x = x, y = y, value = v), wafer)
        vdata = WaferVectorData((x = x, y = y, vx = vx, vy = vy), wafer)
        rgba = [RGBAf(0.2, 0.4, 0.8, 0.5) for _ in 1:4, _ in 1:4]

        # scalar recipes + side panel + annotations + overlays
        fig, ax, side = wafer_figure()
        p = waferheatmap!(ax, sdata)
        add_colorbar!(side, p; label = "test")
        add_kpi_panel!(side, sdata)
        waferscatter!(ax, sdata)
        wafercontour!(ax, sdata; grid_n = 16)
        add_exclusion_ring!(ax, wafer; mm_to_edge = 2.0)
        add_logo!(ax, rgba)
        add_watermark!(ax, rgba)

        # vector recipes (also covers divergence/vorticity/streamline compute paths)
        fig2, ax2, side2 = wafer_figure()
        waferarrows!(ax2, vdata)
        waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, grid_n = 16)
        pd = waferdivergence!(ax2, vdata; grid_n = 16)
        add_colorbar!(side2, pd)
        wafervorticity!(ax2, vdata; grid_n = 16)
    end
end

end
