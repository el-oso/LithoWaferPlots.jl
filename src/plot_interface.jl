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
    waferarrows(data::WaferVectorData; max_arrows=20_000, kwargs...) -> (Figure, Axis, plot)
    waferarrows!(ax, data::WaferVectorData; max_arrows=20_000, kwargs...) -> plot

Arrow plot of vector field. Subsampled to `max_arrows` for readability.
"""
function waferarrows!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferarrows!)
    return ext.waferarrows!(args...; kwargs...)
end

"""
    waferarrows(data::WaferVectorData; max_arrows=20_000, kwargs...) -> (Figure, Axis, plot)
    waferarrows!(ax, data::WaferVectorData; max_arrows=20_000, kwargs...) -> plot

Arrow plot of vector field. Subsampled to `max_arrows` for readability.
"""
function waferarrows(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferarrows)
    return ext.waferarrows(args...; kwargs...)
end

"""
    waferstreamlines(data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> (Figure, Axis, plot)
    waferstreamlines!(ax, data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> plot

Streamline plot via RK4 integration from a uniform seed grid.
"""
function waferstreamlines!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferstreamlines!)
    return ext.waferstreamlines!(args...; kwargs...)
end

"""
    waferstreamlines(data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> (Figure, Axis, plot)
    waferstreamlines!(ax, data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> plot

Streamline plot via RK4 integration from a uniform seed grid.
"""
function waferstreamlines(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferstreamlines)
    return ext.waferstreamlines(args...; kwargs...)
end

"""
    waferdivergence(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
    waferdivergence!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot

Divergence (∂vx/∂x + ∂vy/∂y) of the vector field, displayed as a scalar heatmap.
"""
function waferdivergence!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferdivergence!)
    return ext.waferdivergence!(args...; kwargs...)
end

"""
    waferdivergence(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
    waferdivergence!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot

Divergence (∂vx/∂x + ∂vy/∂y) of the vector field, displayed as a scalar heatmap.
"""
function waferdivergence(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:waferdivergence)
    return ext.waferdivergence(args...; kwargs...)
end

"""
    wafervorticity(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
    wafervorticity!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot

Vorticity (∂vy/∂x − ∂vx/∂y) of the vector field, displayed as a scalar heatmap.
"""
function wafervorticity!(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafervorticity!)
    return ext.wafervorticity!(args...; kwargs...)
end

"""
    wafervorticity(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
    wafervorticity!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot

Vorticity (∂vy/∂x − ∂vx/∂y) of the vector field, displayed as a scalar heatmap.
"""
function wafervorticity(args...; kwargs...)
    ext = _makie_ext()
    ext === nothing && _require_makie(:wafervorticity)
    return ext.wafervorticity(args...; kwargs...)
end
