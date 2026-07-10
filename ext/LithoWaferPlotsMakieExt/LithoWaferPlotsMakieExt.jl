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

export wafer_figure, wafer_cfd_figure, wafer_facet, add_colorbar!, add_kpi_panel!, add_kpi_overlay!
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

        # Every public plotting function below is called through its fully-qualified
        # `LithoWaferPlots.` name, NOT bare. `LithoWaferPlots.<fn>` is the thin stub in
        # src/plot_interface.jl that real users' code actually calls (via `using
        # LithoWaferPlots`); this extension ALSO defines its own same-named `<fn>` (the
        # `@recipe`-generated implementation), which — being a local binding — shadows the
        # `using`-imported stub for bare calls *within this module*. So a bare call here
        # only compiles+caches this extension's own implementation, never the stub's kwcall
        # wrapper the user's call site actually resolves to, leaving it to compile fresh on
        # every real first use regardless of how much the workload otherwise covers.
        # Qualifying forces the stub itself through `Base.get_extension`, caching both layers.

        # scalar recipes + side panel + annotations + overlays
        fig, ax, side = LithoWaferPlots.wafer_figure()
        p = LithoWaferPlots.waferheatmap!(ax, sdata)
        LithoWaferPlots.waferheatmap!(ax, sdata; imagemode = :image)
        # marker (scatter mode)/interpolate (image mode) arrive via mixins, not our own
        # Attributes() block — exercise both passthrough paths so they're cached, not cold.
        LithoWaferPlots.waferheatmap!(ax, sdata; marker = :circle)
        LithoWaferPlots.waferheatmap!(ax, sdata; imagemode = :image, interpolate = false)
        LithoWaferPlots.waferheatmap!(
            ax, sdata; colormap = :plasma,
            field_color = (:black, 0.0), field_strokecolor = :black, field_strokewidth = 1.8f0
        )
        p2 = LithoWaferPlots.waferscatter!(ax, sdata)
        LithoWaferPlots.waferscatter!(ax, sdata; markersize = 4.0f0)
        # marker/strokewidth/alpha arrive via the Scatter attribute mixin, not our own
        # Attributes() block — exercise the passthrough path so it's cached, not cold.
        LithoWaferPlots.waferscatter!(ax, sdata; marker = :diamond, strokewidth = 1.0f0, alpha = 0.8)
        LithoWaferPlots.add_colorbar!(side, p; label = "test")
        LithoWaferPlots.add_colorbar!(side, p2; label = "test")
        LithoWaferPlots.add_kpi_panel!(side, sdata)
        LithoWaferPlots.add_kpi_panel!(side, sdata; fontsize = 8.0f0, title = "Stats")
        LithoWaferPlots.add_kpi_overlay!(ax, sdata)
        LithoWaferPlots.add_kpi_overlay!(ax, sdata; kpis = DEFAULT_KPIS[1:2], position = :lb, sigdigits = 4)
        LithoWaferPlots.wafercontour!(ax, sdata; grid_n = 16)
        LithoWaferPlots.wafercontour!(ax, sdata; levels = 12, colormap = :viridis)
        LithoWaferPlots.wafercontour!(ax, sdata; linewidth = 2.0f0, linestyle = :dash)
        LithoWaferPlots.add_exclusion_ring!(ax, wafer; mm_to_edge = 2.0, label = "edge")
        LithoWaferPlots.add_exclusion_ring!(
            ax, wafer; mm_to_edge = 2.0, label = "edge", color = :black,
            linestyle = :dash, dim_outside = true, dim_alpha = 0.4
        )
        LithoWaferPlots.add_ring_legend!(ax)
        LithoWaferPlots.add_ring_legend!(ax; position = :lb)
        LithoWaferPlots.add_image_overlay!(ax, rgba)
        LithoWaferPlots.add_logo!(ax, rgba)
        LithoWaferPlots.add_watermark!(ax, rgba)
        LithoWaferPlots.add_scale_arrow!(ax, 10.0; label = "10")
        LithoWaferPlots.add_scale_arrow!(ax, 10.0; label = "10", position = :rb)

        # file-path image overlays (distinct code path from the RGBA-matrix one above:
        # `_prepare_overlay_image(::AbstractString, ...)` reads + decodes via FileIO/PNGFiles)
        logo_path = joinpath(mktempdir(), "logo.png")
        Makie.FileIO.save(logo_path, rgba)
        LithoWaferPlots.add_logo!(ax, logo_path; position = :rt, scale = 0.18)
        LithoWaferPlots.add_watermark!(ax, logo_path; opacity = 0.1, scale = 0.55)

        # vector recipes (also covers divergence/vorticity/streamline compute paths)
        fig2, ax2, side2 = LithoWaferPlots.wafer_figure()
        LithoWaferPlots.waferarrows!(ax2, vdata)
        LithoWaferPlots.waferarrows!(ax2, vdata; arrowcolor = :magnitude)
        # max_arrows < n so both `arrow_sample` branches (subsampling code path) compile here
        LithoWaferPlots.waferarrows!(ax2, vdata; max_arrows = 3)
        LithoWaferPlots.waferarrows!(ax2, vdata; max_arrows = 3, arrow_sample = :random)
        LithoWaferPlots.waferarrows!(ax2, vdata; linestyle = :dash, alpha = 0.7)
        # arrowcolor accepting a per-point vector is a distinct code path from :magnitude
        LithoWaferPlots.waferarrows!(ax2, vdata; arrowcolor = collect(1.0:length(vdata.x)), colormap = :plasma)
        p3 = LithoWaferPlots.waferarrows!(ax2, vdata; lengthscale = 8.0, arrowcolor = :magnitude, colormap = :viridis)
        LithoWaferPlots.waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, grid_n = 16)
        LithoWaferPlots.waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, color = :navy, linewidth = 1.2f0)
        LithoWaferPlots.waferstreamlines!(ax2, vdata; n_seeds = 2, max_steps = 5, linestyle = :dot)
        LithoWaferPlots.waferstreamlines!(
            ax2, vdata; draw_boundary = false, draw_fields = false,
            color = :white, n_seeds = 2
        )
        pd = LithoWaferPlots.waferdivergence!(ax2, vdata; grid_n = 16)
        LithoWaferPlots.waferdivergence!(ax2, vdata; colormap = :RdBu)
        LithoWaferPlots.waferdivergence!(ax2, vdata; colormap = :RdBu, markersize = 3.0f0)
        LithoWaferPlots.waferdivergence!(ax2, vdata; grid_n = 16, marker = :circle)
        LithoWaferPlots.waferdivergence!(ax2, vdata; grid_n = 16, colorrange = (-1.0, 1.0))
        LithoWaferPlots.add_colorbar!(side2, pd)
        # image mode: default grid_n is already dense enough to trigger :auto, but force
        # both explicit branches (and the interpolate= passthrough) so they're cached too.
        pd_img = LithoWaferPlots.waferdivergence!(ax2, vdata; imagemode = :image)
        LithoWaferPlots.waferdivergence!(ax2, vdata; imagemode = :scatter)
        LithoWaferPlots.waferdivergence!(ax2, vdata; imagemode = :image, interpolate = false)
        LithoWaferPlots.add_colorbar!(side2, pd_img)
        LithoWaferPlots.wafervorticity!(ax2, vdata; grid_n = 16)
        LithoWaferPlots.wafervorticity!(ax2, vdata; markersize = 3.0f0)
        LithoWaferPlots.wafervorticity!(ax2, vdata; grid_n = 16, marker = :circle)
        LithoWaferPlots.wafervorticity!(ax2, vdata; grid_n = 16, colorrange = (-1.0, 1.0))
        LithoWaferPlots.wafervorticity!(ax2, vdata; imagemode = :image)
        LithoWaferPlots.wafervorticity!(ax2, vdata; imagemode = :scatter)
        LithoWaferPlots.wafervorticity!(ax2, vdata; imagemode = :image, interpolate = false)

        # non-mutating standalone forms (`func` vs `func!`) — auto-create their own Scene,
        # part of the public API (Makie's `@recipe` generates both) but not otherwise
        # exercised anywhere above.
        LithoWaferPlots.waferscatter(sdata)
        LithoWaferPlots.waferheatmap(sdata)
        LithoWaferPlots.wafercontour(sdata)
        LithoWaferPlots.waferarrows(vdata)
        LithoWaferPlots.waferstreamlines(vdata; n_seeds = 2, max_steps = 5)
        LithoWaferPlots.waferdivergence(vdata; grid_n = 16)
        LithoWaferPlots.wafervorticity(vdata; grid_n = 16)

        # combined CFD figure: both scalar backgrounds x both vector overlays
        scale = arrow_scale(0.5, 18.0)
        LithoWaferPlots.wafer_cfd_figure(vdata)
        LithoWaferPlots.wafer_cfd_figure(vdata; scalar = :vorticity, vector = :arrows, scale = scale)
        LithoWaferPlots.wafer_cfd_figure(
            vdata; scalar = :divergence, vector = :streamlines,
            streamline_color = :white, streamline_linewidth = 1.5f0, n_seeds = 2
        )
        p4 = LithoWaferPlots.waferarrows!(ax2, vdata; scale = scale, arrowcolor = :magnitude)
        LithoWaferPlots.add_scale_arrow!(ax2, scale)
        LithoWaferPlots.add_scale_arrow!(ax2, p3)                       # auto ref_magnitude branch
        LithoWaferPlots.add_scale_arrow!(ax2, p3; ref_magnitude = 0.3)  # explicit ref_magnitude branch
        LithoWaferPlots.add_scale_arrow!(ax2, p4)                       # ArrowScale delegation branch

        arrow_scale_from(vdata; ref_fraction = 0.12)

        # grouped-table facet (scatter/heatmap/contour panel functions, shared colorrange)
        tbl = (
            x = vcat(x, x), y = vcat(y, y), value = vcat(v, v),
            grp = vcat(fill(:a, length(x)), fill(:b, length(x))),
        )
        LithoWaferPlots.wafer_facet(tbl, wafer; by = :grp, plot_type = :heatmap, colorrange = extrema(v))
        LithoWaferPlots.wafer_facet(
            tbl, wafer; by = :grp, plot_type = :heatmap,
            colormap = :plasma, colorrange = extrema(v), ncols = 2
        )

        # field-resolved analysis: field numbers, intrafield averaging, per-field facet
        LithoWaferPlots.draw_field_numbers!(ax, full_fields(fields, wafer))

        fx = Float64[]; fy = Float64[]; dx = Float64[]; dy = Float64[]; fval = Float64[]
        for f in fields, ix in (-5.0, 5.0), iy in (-6.0, 6.0)
            push!(fx, f.x_center_mm); push!(fy, f.y_center_mm)
            push!(dx, ix); push!(dy, iy); push!(fval, ix + iy)
        end
        fd = fielded((fx = fx, fy = fy, dx = dx, dy = dy, value = fval), fields; wafer = wafer)
        af = stack_fields(fd; full_only = true)
        LithoWaferPlots.plot_averaged_field(af)
        LithoWaferPlots.plot_averaged_field(af; markersize = 16.0f0)
        LithoWaferPlots.field_facet(fd; full_only = true, colorrange = extrema(fval))

        # heatmap with markersize + field overlay together (die-level-yield-map pattern)
        LithoWaferPlots.waferheatmap!(
            ax, sdata; markersize = 14.0f0, colormap = :RdYlGn,
            field_color = (:black, 0.0), field_strokecolor = :gray50, field_strokewidth = 0.7f0
        )
    end
end

end
