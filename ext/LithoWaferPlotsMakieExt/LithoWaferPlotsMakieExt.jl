module LithoWaferPlotsMakieExt

using Makie
using LithoWaferPlots
using LithoWaferPlots: WaferSpec, WaferData, WaferVectorData, WaferField,
    wafer_polygon, inside_wafer, field_bounds,
    ColorScale, normalize, DEFAULT_KPIS, AbstractKPI,
    name, compute, format_value,
    divergence, vorticity, _vector_to_grid,
    FieldedData, AveragedField, filter_full, field_average_profiles, serpentine_numbers,
    ArrowScale, _nice_magnitude
using NearestNeighbors: KDTree, knn, knn!
using PrecompileTools: @compile_workload
using Random: randperm
using Statistics: median
using Tables

include("wafer_shape.jl")
include("streamlines.jl")
include("layout.jl")
include("overlay.jl")
include("recipes_scalar.jl")
include("recipes_vector.jl")

export wafer_figure, wafer_cfd_figure, wafer_facet, add_colorbar!, add_kpi_panel!
export plot_averaged_field, field_facet, draw_field_numbers!
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
# methods so the first plot in a session is fast. Covers every recipe, every public
# plotting/layout/annotation/overlay function, and the field-resolved-analysis figures
# so no public plotting path compiles on first use.
@compile_workload begin
    let wafer = WaferSpec(300.0),
            x = Float64[-80.0, 0.0, 80.0, 40.0, -40.0],
            y = Float64[-80.0, 0.0, 80.0, -40.0, 40.0],
            v = Float64[1.0, 2.0, 3.0, 2.0, 1.0],
            vx = Float64[0.1, -0.2, 0.3, -0.1, 0.2],
            vy = Float64[0.2, 0.1, -0.3, 0.2, -0.1]

        # non-empty `fields` so `draw_fields!`'s `poly!(...)` loop (past its `isempty`
        # fast path) compiles here rather than on a real user's first field-grouped plot.
        fields = field_grid([((c - 2) * 26.0, (r - 2) * 33.0) for r in 1:3, c in 1:3], (26.0, 33.0); wafer = wafer)
        sdata = WaferData((x = x, y = y, value = v), wafer; fields = fields)
        vdata = WaferVectorData((x = x, y = y, vx = vx, vy = vy), wafer; fields = fields)
        # also compile the default-`wafer`-argument constructor overload (WaferSpec(300.0)
        # matches the default, so this is the same wafer, just via the omitted-arg method)
        WaferData((x = x, y = y, value = v); fields = fields)
        WaferVectorData((x = x, y = y, vx = vx, vy = vy); fields = fields)
        rgba = [RGBAf(0.2, 0.4, 0.8, 0.5) for _ in 1:4, _ in 1:4]

        # scalar recipes + side panel + annotations + overlays
        fig, ax, side = wafer_figure()
        p = waferheatmap!(ax, sdata)
        waferheatmap!(ax, sdata; imagemode = :image)
        waferheatmap!(
            ax, sdata; colormap = :plasma,
            field_color = (:black, 0.0), field_strokecolor = :black, field_strokewidth = 1.8f0
        )
        add_colorbar!(side, p; label = "test")
        add_kpi_panel!(side, sdata)
        waferscatter!(ax, sdata)
        wafercontour!(ax, sdata; grid_n = 16)
        add_exclusion_ring!(ax, wafer; mm_to_edge = 2.0, label = "edge")
        add_ring_legend!(ax)
        add_image_overlay!(ax, rgba)
        add_logo!(ax, rgba)
        add_watermark!(ax, rgba)
        add_scale_arrow!(ax, 10.0; label = "10")
        add_scale_arrow!(ax, 10.0; label = "10", position = :rb)

        # vector recipes (also covers divergence/vorticity/streamline compute paths)
        fig2, ax2, side2 = wafer_figure()
        waferarrows!(ax2, vdata)
        waferarrows!(ax2, vdata; arrowcolor = :magnitude)
        waferarrows!(ax2, vdata; lengthscale = 8.0, arrowcolor = :magnitude, colormap = :viridis)
        waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, grid_n = 16)
        pd = waferdivergence!(ax2, vdata; grid_n = 16)
        add_colorbar!(side2, pd)
        wafervorticity!(ax2, vdata; grid_n = 16)

        # combined CFD figure: both scalar backgrounds x both vector overlays
        scale = arrow_scale(0.5, 18.0)
        wafer_cfd_figure(vdata)
        wafer_cfd_figure(vdata; scalar = :vorticity, vector = :arrows, scale = scale)

        # grouped-table facet (scatter/heatmap/contour panel functions, shared colorrange)
        tbl = (
            x = vcat(x, x), y = vcat(y, y), value = vcat(v, v),
            grp = vcat(fill(:a, length(x)), fill(:b, length(x))),
        )
        wafer_facet(tbl, wafer; by = :grp, plot_type = :heatmap, colorrange = extrema(v))

        # field-resolved analysis: field numbers, intrafield averaging, per-field facet
        draw_field_numbers!(ax, full_fields(fields, wafer))

        fx = Float64[]; fy = Float64[]; dx = Float64[]; dy = Float64[]; fval = Float64[]
        for f in fields, ix in (-5.0, 5.0), iy in (-6.0, 6.0)
            push!(fx, f.x_center_mm); push!(fy, f.y_center_mm)
            push!(dx, ix); push!(dy, iy); push!(fval, ix + iy)
        end
        fd = fielded((fx = fx, fy = fy, dx = dx, dy = dy, value = fval), fields; wafer = wafer)
        af = stack_fields(fd; full_only = true)
        plot_averaged_field(af)
        field_facet(fd; full_only = true, colorrange = extrema(fval))
    end
end

end
