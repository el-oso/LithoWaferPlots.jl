"""
Plotting function stubs.

Implementations live in `ext/LithoWaferPlotsMakieExt`. These stubs are exported
from the parent package so that `using LithoWaferPlots, CairoMakie` (or any Makie
backend) makes all plot functions available without an explicit `using` of the
extension module.
"""

_makie_ext() = Base.get_extension(LithoWaferPlots, :LithoWaferPlotsMakieExt)

function _require_makie(fn::Symbol)
    error(
        "LithoWaferPlots plotting function `$fn` requires a Makie backend.\n" *
            "Load one before calling it, e.g.:\n\n" *
            "    using CairoMakie    # for file/notebook rendering\n" *
            "    using GLMakie       # for interactive desktop windows\n" *
            "    using WGLMakie      # for browser/Pluto notebooks\n"
    )
end

# ── layout functions ──────────────────────────────────────────────────────────

"""
    add_exclusion_ring!(ax, wafer::WaferSpec; mm_to_edge, label="", kwargs...)

Draw a dashed circle at `mm_to_edge` mm from the wafer edge. Composes with any recipe
already on `ax` — call after the primary plot.

Keywords:
- `mm_to_edge::Real`: distance from the wafer edge in mm (required)
- `label::String`: legend entry; empty string = no legend entry
- `color`: ring colour (default `:red`)
- `linewidth`: line width (default `1.0f0`)
- `linestyle`: `:dash` (default), `:dot`, `:dashdot`, etc.
- `dim_outside::Bool`: overlay a semi-transparent fill between the ring and the
  wafer boundary (default `false`)
- `dim_color`: dim overlay colour (default `:black`)
- `dim_alpha::Real`: dim overlay opacity 0–1 (default `0.35`)

Call multiple times for several rings. Follow with `add_ring_legend!(ax)` to show labels.

Requires a Makie backend.
"""
function add_exclusion_ring!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_exclusion_ring!)
    return ext.add_exclusion_ring!(args...; kwargs...)
end

"""
    add_ring_legend!(ax; position=:rt, framevisible=false, kwargs...)

Show a legend on `ax` collecting all labeled elements (e.g., exclusion rings).
Thin wrapper around Makie's `axislegend`.

Requires a Makie backend.
"""
function add_ring_legend!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_ring_legend!)
    return ext.add_ring_legend!(args...; kwargs...)
end

"""
    add_image_overlay!(target, image; position=:rt, scale=0.15, margin=0.04, opacity=1.0, interpolate=true)

Overlay `image` on `target` (an `Axis` or `Figure`) at a fixed, aspect-preserving position.
The overlay stays put and keeps its aspect ratio regardless of zoom or data range.

- `image`: path to an image file (PNG with alpha, …) or an `AbstractMatrix` of colors.
- `position`: `:lt :ct :rt :lc :center :rc :lb :cb :rb`, or an `(fx, fy)` tuple (image centre
  in `0..1` of the target).
- `scale`: image height as a fraction of the target height (width follows the image aspect).
- `margin`: edge padding as a fraction of the target's smaller dimension.
- `opacity`: global alpha multiplier `0..1`, applied on top of the image's own alpha.

Requires a Makie backend.
"""
function add_image_overlay!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_image_overlay!)
    return ext.add_image_overlay!(args...; kwargs...)
end

"""
    add_logo!(target, image; position=:rt, scale=0.12, margin=0.03, opacity=1.0, kwargs...)

Place a logo image in a corner of `target` (an `Axis` or `Figure`). Convenience wrapper over
`add_image_overlay!` with small, corner-anchored defaults. Requires a Makie backend.
"""
function add_logo!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_logo!)
    return ext.add_logo!(args...; kwargs...)
end

"""
    add_watermark!(target, image; position=:center, scale=0.5, opacity=0.15, kwargs...)

Place a large, faded watermark image over `target` (an `Axis` or `Figure`). Convenience
wrapper over `add_image_overlay!` with centred, semi-transparent defaults.
Requires a Makie backend.
"""
function add_watermark!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_watermark!)
    return ext.add_watermark!(args...; kwargs...)
end

"""
    add_scale_arrow!(ax, length_data; label="", position=:rb, kwargs...)

Draw a horizontal reference arrow `length_data` long in data (mm) coordinates on a wafer
`Axis`, with `label` centred above it. Shares the `lengthscale` of `waferarrows!`: pass
`length_data = ref * lengthscale` and `label = "\$ref nm"` so the arrow reads as a scale.

Keywords: `label`, `position` (`:rb` default), `color`, `linewidth`, `head_frac`,
`head_angle`, `fontsize`, `margin`, `textcolor`. Requires a Makie backend.
"""
function add_scale_arrow!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_scale_arrow!)
    return ext.add_scale_arrow!(args...; kwargs...)
end

"""
    wafer_cfd_figure(vdata::WaferVectorData; scalar=:divergence, vector=:streamlines, kwargs...)

Create a combined CFD plot: scalar background (divergence or vorticity) with a streamline or
arrow overlay in one call. Returns `(fig, ax, side)`.

Keywords:
- `scalar`: `:divergence` (default) or `:vorticity`
- `vector`: `:streamlines` (default), `:arrows`, or `:none`
- `colormap`: override auto colormap (`:RdBu` for divergence, `Reverse(:RdBu)` for vorticity)
- `scalar_label`: colorbar label (auto if omitted)
- `streamline_color`: color of streamlines (default `:white`)
- `n_seeds`, `max_steps`: streamline trace parameters
- `arrowcolor`: arrow color when `vector=:arrows`

Requires a Makie backend: `using CairoMakie` or `using GLMakie`.
"""
function wafer_cfd_figure(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafer_cfd_figure)
    return ext.wafer_cfd_figure(args...; kwargs...)
end

"""
    wafer_facet(table, wafer::WaferSpec; by, kwargs...) -> Figure

Create a grid of wafer maps from grouped tabular data.

Keywords:
- `by::Symbol`: column whose unique values become facet panels (required)
- `x::Symbol = :x`, `y::Symbol = :y`, `value::Symbol = :value`: data columns
- `plot_type::Symbol = :heatmap`: `:scatter`, `:heatmap`, or `:contour`
- `colormap`: colormap for all panels (default `:inferno`)
- `colorrange`: `nothing` for per-panel auto-scaling, or `(lo, hi)` for a shared colorbar
- `ncols::Int = 3`: columns in the grid
- `resolution`: auto-sized from panel count if omitted

Requires a Makie backend.
"""
function wafer_facet(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafer_facet)
    return ext.wafer_facet(args...; kwargs...)
end

"""
    plot_averaged_field(af::AveragedField; kwargs...) -> Figure

Plot an intrafield average (from `stack_fields`) with slit/scan marginal profiles and a
KPI panel. Requires a Makie backend.
"""
function plot_averaged_field(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:plot_averaged_field)
    return ext.plot_averaged_field(args...; kwargs...)
end

"""
    field_facet(fd::FieldedData; kwargs...) -> Figure

One panel per exposure field in field-local coordinates. Requires a Makie backend.
"""
function field_facet(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:field_facet)
    return ext.field_facet(args...; kwargs...)
end

"""
    draw_field_numbers!(ax, fields; numbers=nothing, kwargs...)

Label each exposure field with its shot number (serpentine order by default). Requires a
Makie backend.
"""
function draw_field_numbers!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:draw_field_numbers!)
    return ext.draw_field_numbers!(args...; kwargs...)
end

"""
    wafer_figure(; resolution=(900,650), kwargs...) -> (Figure, Axis, GridLayout)

Create a Figure with the standard wafer layout: main wafer Axis on the left,
side panel (colorbar + KPI panel) on the right.

Requires a Makie backend: `using CairoMakie` or `using GLMakie`.
"""
function wafer_figure(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafer_figure)
    return ext.wafer_figure(args...; kwargs...)
end

"""
    add_colorbar!(side, plot_obj; label="", kwargs...)

Add a `Colorbar` to the top slot of the side panel returned by `wafer_figure`.
"""
function add_colorbar!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_colorbar!)
    return ext.add_colorbar!(args...; kwargs...)
end

"""
    add_kpi_panel!(side, data::WaferData; kpis=DEFAULT_KPIS)

Compute and display KPIs in the bottom slot of the side panel.
Pass a custom `kpis` vector of `AbstractKPI` objects to override the defaults.
"""
function add_kpi_panel!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:add_kpi_panel!)
    return ext.add_kpi_panel!(args...; kwargs...)
end

# ── scalar plot wrappers ──────────────────────────────────────────────────────

"""
    waferscatter(data::WaferData; kwargs...) -> (Figure, Axis, plot)
    waferscatter!(ax, data::WaferData; kwargs...) -> plot

Scatter plot of wafer data with auto colormap and wafer boundary overlay.
"""
function waferscatter!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferscatter!)
    return ext.waferscatter!(args...; kwargs...)
end

"""
    waferscatter(data::WaferData; kwargs...) -> (Figure, Axis, plot)
    waferscatter!(ax, data::WaferData; kwargs...) -> plot

Scatter plot of wafer data with auto colormap and wafer boundary overlay.
"""
function waferscatter(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferscatter)
    return ext.waferscatter(args...; kwargs...)
end

"""
    waferheatmap(data::WaferData; kwargs...) -> (Figure, Axis, plot)
    waferheatmap!(ax, data::WaferData; kwargs...) -> plot

Heatmap-style plot using rectangular scatter markers.
Use `percentile_clip` to reduce outlier influence on the color scale.
"""
function waferheatmap!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferheatmap!)
    return ext.waferheatmap!(args...; kwargs...)
end

"""
    waferheatmap(data::WaferData; kwargs...) -> (Figure, Axis, plot)
    waferheatmap!(ax, data::WaferData; kwargs...) -> plot

Heatmap-style plot using rectangular scatter markers.
Use `percentile_clip` to reduce outlier influence on the color scale.
"""
function waferheatmap(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferheatmap)
    return ext.waferheatmap(args...; kwargs...)
end

"""
    wafercontour(data::WaferData; levels=10, grid_n=256, kwargs...) -> (Figure, Axis, plot)
    wafercontour!(ax, data::WaferData; levels=10, grid_n=256, kwargs...) -> plot

Contour plot. Data is interpolated to a regular `grid_n×grid_n` grid first.
"""
function wafercontour!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafercontour!)
    return ext.wafercontour!(args...; kwargs...)
end

"""
    wafercontour(data::WaferData; levels=10, grid_n=256, kwargs...) -> (Figure, Axis, plot)
    wafercontour!(ax, data::WaferData; levels=10, grid_n=256, kwargs...) -> plot

Contour plot. Data is interpolated to a regular `grid_n×grid_n` grid first.
"""
function wafercontour(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafercontour)
    return ext.wafercontour(args...; kwargs...)
end

# ── vector plot wrappers ──────────────────────────────────────────────────────

"""
    waferarrows(data::WaferVectorData; max_arrows=4_000, kwargs...) -> (Figure, Axis, plot)
    waferarrows!(ax, data::WaferVectorData; max_arrows=4_000, kwargs...) -> plot

Arrow plot of vector field. Subsampled to `max_arrows` for readability.
"""
function waferarrows!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferarrows!)
    return ext.waferarrows!(args...; kwargs...)
end

"""
    waferarrows(data::WaferVectorData; max_arrows=4_000, kwargs...) -> (Figure, Axis, plot)
    waferarrows!(ax, data::WaferVectorData; max_arrows=4_000, kwargs...) -> plot

Arrow plot of vector field. Subsampled to `max_arrows` for readability.
"""
function waferarrows(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferarrows)
    return ext.waferarrows(args...; kwargs...)
end

"""
    waferstreamlines(data::WaferVectorData; n_seeds=20, max_steps=300, grid_n=200, kwargs...) -> (Figure, Axis, plot)
    waferstreamlines!(ax, data::WaferVectorData; n_seeds=20, max_steps=300, grid_n=200, kwargs...) -> plot

Streamline plot via RK4 integration from a uniform seed grid. The velocity field is
interpolated once to a `grid_n × grid_n` grid and sampled bilinearly during tracing.
"""
function waferstreamlines!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferstreamlines!)
    return ext.waferstreamlines!(args...; kwargs...)
end

"""
    waferstreamlines(data::WaferVectorData; n_seeds=20, max_steps=300, grid_n=200, kwargs...) -> (Figure, Axis, plot)
    waferstreamlines!(ax, data::WaferVectorData; n_seeds=20, max_steps=300, grid_n=200, kwargs...) -> plot

Streamline plot via RK4 integration from a uniform seed grid. The velocity field is
interpolated once to a `grid_n × grid_n` grid and sampled bilinearly during tracing.
"""
function waferstreamlines(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferstreamlines)
    return ext.waferstreamlines(args...; kwargs...)
end

"""
    waferdivergence(data::WaferVectorData; grid_n=256, k=4, kwargs...) -> (Figure, Axis, plot)
    waferdivergence!(ax, data::WaferVectorData; grid_n=256, k=4, kwargs...) -> plot

Divergence (∂vx/∂x + ∂vy/∂y) of the vector field, displayed as a scalar heatmap.
`k` is the IDW neighbour count (lower = faster, less smooth).
"""
function waferdivergence!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferdivergence!)
    return ext.waferdivergence!(args...; kwargs...)
end

"""
    waferdivergence(data::WaferVectorData; grid_n=256, k=4, kwargs...) -> (Figure, Axis, plot)
    waferdivergence!(ax, data::WaferVectorData; grid_n=256, k=4, kwargs...) -> plot

Divergence (∂vx/∂x + ∂vy/∂y) of the vector field, displayed as a scalar heatmap.
`k` is the IDW neighbour count (lower = faster, less smooth).
"""
function waferdivergence(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferdivergence)
    return ext.waferdivergence(args...; kwargs...)
end

"""
    wafervorticity(data::WaferVectorData; grid_n=256, k=4, kwargs...) -> (Figure, Axis, plot)
    wafervorticity!(ax, data::WaferVectorData; grid_n=256, k=4, kwargs...) -> plot

Vorticity (∂vy/∂x − ∂vx/∂y) of the vector field, displayed as a scalar heatmap.
`k` is the IDW neighbour count (lower = faster, less smooth).
"""
function wafervorticity!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafervorticity!)
    return ext.wafervorticity!(args...; kwargs...)
end

"""
    wafervorticity(data::WaferVectorData; grid_n=256, k=4, kwargs...) -> (Figure, Axis, plot)
    wafervorticity!(ax, data::WaferVectorData; grid_n=256, k=4, kwargs...) -> plot

Vorticity (∂vy/∂x − ∂vx/∂y) of the vector field, displayed as a scalar heatmap.
`k` is the IDW neighbour count (lower = faster, less smooth).
"""
function wafervorticity(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafervorticity)
    return ext.wafervorticity(args...; kwargs...)
end
