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
"""
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
        waferarrows!(ax, vdata; draw_boundary = false, draw_fields = false, arrowcolor = arrowcolor)
    elseif vector !== :none
        error("vector must be :streamlines, :arrows, or :none, got :$vector")
    end

    add_colorbar!(side, p; label = auto_label)
    return fig, ax, side
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
