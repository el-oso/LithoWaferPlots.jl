"""
Full figure layout: wafer axis + colorbar + KPI panel.

Layout:
  Figure
  └── GridLayout [1 row × 2 cols]
      ├── [1,1] Axis  (aspect=DataAspect, no decorations)  ← wafer plot
      └── [1,2] GridLayout (side panel, 30% width)
              ├── [1,1] Colorbar
              └── [2,1] KPI text panel (Box + labels)
"""

"""
    wafer_figure(; figure_kwargs...) -> (fig, ax, side_layout)

Create a Figure with the standard wafer layout. Returns the Figure, the main
wafer Axis, and the side GridLayout for colorbar/KPI insertion.
"""
function wafer_figure(; resolution = (900, 650), figure_kwargs...)
    fig = Figure(; size = resolution, figure_kwargs...)
    gl = fig[1, 1] = GridLayout()

    ax = Axis(
        gl[1, 1];
        aspect = DataAspect(),
        xgridvisible = false, ygridvisible = false,
        topspinevisible = false, rightspinevisible = false,
        xlabel = "x (mm)", ylabel = "y (mm)"
    )

    side = gl[1, 2] = GridLayout(; tellwidth = true)
    colsize!(gl, 2, Relative(0.32))

    return fig, ax, side
end

"""
    add_colorbar!(side, plot_obj; label="", kwargs...)

Add a `Colorbar` to the top slot of the side panel.
`plot_obj` is the recipe plot returned by a wafer recipe call.
The colorbar is attached to the first `Scatter` child plot (which carries the
colormap and colorrange), avoiding ambiguity when field `Poly` patches are present.
"""
function add_colorbar!(side, plot_obj; label::String = "", kwargs...)
    # Scatter-based recipes (waferscatter, waferheatmap scatter mode): the first
    # Scatter child carries colormap + colorrange (actual data values) directly.
    scatter_idx = findfirst(p -> p isa Scatter, plot_obj.plots)
    if scatter_idx !== nothing
        Colorbar(side[1, 1], plot_obj.plots[scatter_idx]; label, vertical = true, kwargs...)
        return nothing
    end

    # WaferHeatmap image mode: single Image child; build Colorbar from the recipe's
    # WaferData input so limits reflect percentile-clipped range.
    image_idx = findfirst(p -> p isa Image, plot_obj.plots)
    if image_idx !== nothing
        input_data = plot_obj[1][]
        mask = inside_wafer(input_data.x, input_data.y, input_data.wafer)
        vals = filter(isfinite, input_data.values[mask])
        pc = haskey(plot_obj.attributes, :percentile_clip) ? plot_obj[:percentile_clip][] : 0.0
        cs = ColorScale(vals; percentile_clip = pc)
        cmap = plot_obj[:colormap][]
        Colorbar(
            side[1, 1]; colormap = cmap, limits = (Float32(cs.vmin), Float32(cs.vmax)),
            label, vertical = true, kwargs...
        )
        return nothing
    end

    # Contour recipe: Makie's Colorbar constructor recurses into Text children
    # (contour labels) and hits a "multiple colormaps" error.  Build from
    # explicit colormap + data extrema instead.
    contour_idx = findfirst(p -> p isa Plot{Makie.contour}, plot_obj.plots)
    if contour_idx !== nothing
        input_data = plot_obj[1][]
        vals = filter(isfinite, input_data.values)
        lo, hi = isempty(vals) ? (0.0, 1.0) : extrema(vals)
        cmap = plot_obj[:colormap][]
        Colorbar(side[1, 1]; colormap = cmap, limits = (lo, hi), label, vertical = true, kwargs...)
        return nothing
    end

    # Fallback for any other recipe.
    Colorbar(side[1, 1], plot_obj; label, vertical = true, kwargs...)
    return nothing
end

"""
    wafer_cfd_figure(vdata::WaferVectorData; scalar=:divergence, vector=:streamlines, kwargs...)

Create a combined CFD plot: scalar background field with a streamline or arrow overlay.
Returns `(fig, ax, side)` so that `add_kpi_panel!` or extra plot calls can be appended.

Keywords:
- `scalar`: `:divergence` (default) or `:vorticity`
- `vector`: `:streamlines` (default), `:arrows`, or `:none`
- `colormap`: override the auto colormap (`:RdBu` for divergence, `Reverse(:RdBu)` for vorticity)
- `scalar_label`: colorbar label; auto-set from `scalar` if omitted
- `streamline_color`: line color for the streamline overlay (default `:white`)
- `streamline_linewidth`: line width (default `1.5f0`)
- `n_seeds`, `max_steps`: passed to `waferstreamlines!`
- `arrowcolor`: arrow colour when `vector=:arrows`
- `lengthscale`: arrow length scale when `vector=:arrows` (default `1.0`)
- `scale_arrow`: when `vector=:arrows`, draw a reference [`add_scale_arrow!`](@ref) sized to
  the nice-rounded median `|v|` (default `true`); set `false` to omit it
"""
# Round to a "nice" 1/2/5 × 10^k value for the reference-arrow label.
function _nice_magnitude(v::Float64)
    v <= 0 && return v
    p = 10.0^floor(log10(v))
    m = v / p
    nice = m < 1.5 ? 1.0 : m < 3.0 ? 2.0 : m < 7.0 ? 5.0 : 10.0
    return nice * p
end

function wafer_cfd_figure(
        vdata::WaferVectorData;
        scalar::Symbol = :divergence,
        vector::Symbol = :streamlines,
        colormap = nothing,
        scalar_label = nothing,
        streamline_color = :white,
        streamline_linewidth = 1.5f0,
        n_seeds = 20,
        max_steps = 300,
        arrowcolor = :white,
        lengthscale = 1.0,
        scale_arrow::Bool = true,
        resolution = (900, 650),
        figure_kwargs...
    )
    fig, ax, side = wafer_figure(; resolution, figure_kwargs...)

    auto_cmap = colormap === nothing ?
        (scalar === :divergence ? :RdBu : Reverse(:RdBu)) : colormap
    auto_label = scalar_label === nothing ?
        (scalar === :divergence ? "Divergence (a.u.)" : "Vorticity (a.u.)") : scalar_label

    p = if scalar === :divergence
        waferdivergence!(ax, vdata; colormap = auto_cmap)
    elseif scalar === :vorticity
        wafervorticity!(ax, vdata; colormap = auto_cmap)
    else
        error("scalar must be :divergence or :vorticity, got :$scalar")
    end

    if vector === :streamlines
        waferstreamlines!(
            ax, vdata;
            draw_boundary = false, draw_fields = false,
            color = streamline_color, linewidth = streamline_linewidth,
            n_seeds = n_seeds, max_steps = max_steps
        )
    elseif vector === :arrows
        waferarrows!(
            ax, vdata;
            draw_boundary = false, draw_fields = false,
            arrowcolor = arrowcolor, lengthscale = lengthscale
        )
        if scale_arrow
            ref = _nice_magnitude(median(hypot.(Float64.(vdata.vx), Float64.(vdata.vy))))
            ref > 0 && add_scale_arrow!(ax, ref * lengthscale; label = string(ref), position = :rb)
        end
    elseif vector !== :none
        error("vector must be :streamlines, :arrows, or :none, got :$vector")
    end

    add_colorbar!(side, p; label = auto_label)
    return fig, ax, side
end

"""
    add_exclusion_ring!(ax, wafer::WaferSpec; mm_to_edge, label="", kwargs...)

Draw a dashed circle at `mm_to_edge` mm from the wafer edge on `ax`.

Keywords:
- `mm_to_edge`: distance from the wafer edge in mm (required)
- `label`: legend entry text; empty string = no legend entry
- `color`: ring line colour (default `:red`)
- `linewidth`: ring line width (default `1.0f0`)
- `linestyle`: `:dash` (default), `:dot`, `:dashdot`, etc.
- `dim_outside`: when `true`, draw a semi-transparent overlay on the region
  between the ring and the wafer boundary (default `false`)
- `dim_color`: overlay fill colour (default `:black`)
- `dim_alpha`: overlay opacity, 0–1 (default `0.35`)
- `n`: circle polygon resolution (default `256`)

Call multiple times with different `mm_to_edge` values to draw several rings.
Call `add_ring_legend!(ax)` afterwards to show a legend.
"""
function add_exclusion_ring!(
        ax, wafer::WaferSpec;
        mm_to_edge::Real,
        label::String = "",
        color = :red,
        linewidth = 1.0f0,
        linestyle = :dash,
        dim_outside::Bool = false,
        dim_color = :black,
        dim_alpha::Real = 0.35,
        n::Int = 256,
    )
    r_ring = wafer.diameter_mm / 2.0 - mm_to_edge
    r_ring > 0 || error("mm_to_edge ($mm_to_edge mm) is larger than the wafer radius")
    r_wafer = wafer.diameter_mm / 2.0

    if dim_outside
        _draw_dim_annulus!(ax, r_ring, r_wafer; color = dim_color, alpha = dim_alpha, n)
    end

    _draw_ring!(ax, r_ring; label, color, linewidth, linestyle, n)
    return nothing
end

"""
    add_ring_legend!(ax; position=:rt, framevisible=false, kwargs...)

Show a legend on `ax` for all labeled elements (e.g., exclusion rings drawn with
a non-empty `label`). Thin wrapper around `axislegend`.
"""
function add_ring_legend!(ax; position = :rt, framevisible = false, kwargs...)
    axislegend(ax; position, framevisible, kwargs...)
    return nothing
end

"""
    wafer_facet(table, wafer::WaferSpec; by, kwargs...) -> Figure

Create a grid of wafer maps from grouped tabular data — one panel per unique value
of the `by` column. Works with any Tables.jl-compatible source (DataFrame, NamedTuple
of vectors, CSV row table, etc.).

Keywords:
- `by::Symbol`: column whose unique values become facet panels (required)
- `x::Symbol = :x`: x-coordinate column
- `y::Symbol = :y`: y-coordinate column
- `value::Symbol = :value`: measurement column
- `plot_type::Symbol = :heatmap`: `:scatter`, `:heatmap`, or `:contour`
- `colormap`: colormap for all panels (default `:inferno`)
- `colorrange`: `nothing` for per-panel auto-scaling, or `(lo, hi)` for a shared
  scale with a shared colorbar below the grid
- `ncols::Int = 3`: columns in the grid (rows filled automatically)
- `resolution`: auto-sized from panel count if omitted
- `figure_kwargs...`: forwarded to `Figure`

Requires a Makie backend.
"""
function wafer_facet(
        table, wafer::WaferSpec;
        by::Symbol,
        x::Symbol = :x,
        y::Symbol = :y,
        value::Symbol = :value,
        plot_type::Symbol = :heatmap,
        colormap = :inferno,
        colorrange = nothing,
        ncols::Int = 3,
        resolution = nothing,
        figure_kwargs...
    )
    cols = Tables.columns(table)
    by_col = collect(Tables.getcolumn(cols, by))
    x_col = collect(Float64.(Tables.getcolumn(cols, x)))
    y_col = collect(Float64.(Tables.getcolumn(cols, y)))
    v_col = collect(Tables.getcolumn(cols, value))

    groups = unique(by_col)
    ngroups = length(groups)
    nrows = cld(ngroups, ncols)

    panel_w = 270
    panel_h = 290
    sz = resolution === nothing ?
        (panel_w * min(ngroups, ncols), panel_h * nrows + (colorrange !== nothing ? 60 : 0)) :
        resolution
    fig = Figure(; size = sz, figure_kwargs...)
    gl = fig[1, 1] = GridLayout()

    plot_fn! = if plot_type === :heatmap
        (ax, wd; kw...) -> waferheatmap!(ax, wd; imagemode = :scatter, kw...)
    elseif plot_type === :scatter
        (ax, wd; kw...) -> waferscatter!(ax, wd; kw...)
    elseif plot_type === :contour
        (ax, wd; kw...) -> wafercontour!(ax, wd; kw...)
    else
        error("plot_type must be :heatmap, :scatter, or :contour, got :$plot_type")
    end

    for (k, g) in enumerate(groups)
        row, col = fldmod1(k, ncols)
        cell = gl[row, col] = GridLayout()
        ax = Axis(
            cell[2, 1];
            aspect = DataAspect(),
            xgridvisible = false, ygridvisible = false,
            topspinevisible = false, rightspinevisible = false,
            xticklabelsize = 8.0f0, yticklabelsize = 8.0f0,
        )
        Label(cell[1, 1]; text = string(g), fontsize = 11.0f0, tellwidth = false)

        mask = isequal.(by_col, g)
        sub = (x = x_col[mask], y = y_col[mask], value = v_col[mask])
        wdata = WaferData(sub, wafer)

        p = plot_fn!(ax, wdata; colormap)

        if colorrange !== nothing
            scatter_idx = findfirst(plt -> plt isa Scatter, p.plots)
            if scatter_idx !== nothing
                p.plots[scatter_idx].colorrange[] =
                    (Float32(colorrange[1]), Float32(colorrange[2]))
            end
        end
    end

    if colorrange !== nothing
        Colorbar(
            gl[nrows + 1, 1:min(ngroups, ncols)];
            colormap,
            limits = (Float32(colorrange[1]), Float32(colorrange[2])),
            vertical = false,
            label = string(value),
            height = 16,
        )
        rowsize!(gl, nrows + 1, Fixed(50))
    end

    return fig
end

"""
    add_kpi_panel!(side, data::WaferData; kpis=DEFAULT_KPIS)

Compute KPIs and render a label grid in the bottom slot of the side panel.
Each KPI gets its own row with name on the left and value on the right.
Uses `Label` blocks (not `text!`) so content never clips to an Axis frame.
"""
function add_kpi_panel!(side, data::WaferData; kpis::AbstractVector{<:AbstractKPI} = DEFAULT_KPIS)
    vals = filter(isfinite, data.values)
    isempty(vals) && return nothing

    kpi_gl = side[2, 1] = GridLayout()

    Label(
        kpi_gl[1, 1]; text = "KPIs",
        fontsize = 11.0f0, font = :bold, halign = :center, tellwidth = false
    )

    for (i, k) in enumerate(kpis)
        nm = name(k)
        val = format_value(k, compute(k, vals))
        # Fixed-width name column (12 chars) + value in a single monospaced label
        line = rpad(nm, 12) * val
        Label(
            kpi_gl[i + 1, 1]; text = line,
            fontsize = 9.0f0, halign = :left, tellwidth = false,
            font = "DejaVu Sans Mono"
        )
    end

    rowgap!(kpi_gl, 1)
    rowsize!(side, 2, Auto())
    return nothing
end
