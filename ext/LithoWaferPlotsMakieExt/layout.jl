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
function wafer_figure(; resolution=(900, 650), figure_kwargs...)
    fig = Figure(; size=resolution, figure_kwargs...)
    gl = fig[1, 1] = GridLayout()

    ax = Axis(gl[1, 1];
        aspect=DataAspect(),
        xgridvisible=false, ygridvisible=false,
        topspinevisible=false, rightspinevisible=false,
        xlabel="x (mm)", ylabel="y (mm)")

    side = gl[1, 2] = GridLayout(; tellwidth=true)
    colsize!(gl, 2, Relative(0.22))

    return fig, ax, side
end

"""
    add_colorbar!(side, plot_obj; label="", colormap=:viridis, limits=(0.0, 1.0))

Add a `Colorbar` to the top slot of the side panel.
`plot_obj` should be the Makie plot object returned by a recipe (has `.colorrange`).
"""
function add_colorbar!(side, plot_obj; label::String="", kwargs...)
    Colorbar(side[1, 1], plot_obj; label, vertical=true, kwargs...)
    return nothing
end

"""
    add_kpi_panel!(side, data::WaferData; kpis=DEFAULT_KPIS)

Compute KPIs and render a two-column text table in the bottom slot of the side panel.
"""
function add_kpi_panel!(side, data::WaferData; kpis::AbstractVector{<:AbstractKPI}=DEFAULT_KPIS)
    vals = filter(isfinite, data.values)
    isempty(vals) && return nothing

    rows = ["$(name(k))  $(format_value(k, compute(k, vals)))" for k in kpis]
    text_content = join(rows, "\n")

    ax_kpi = Axis(side[2, 1];
        aspect=nothing,
        xgridvisible=false, ygridvisible=false,
        xticksvisible=false, yticksvisible=false,
        xticklabelsvisible=false, yticklabelsvisible=false,
        topspinevisible=true, bottomspinevisible=true,
        leftspinevisible=true, rightspinevisible=true,
        title="KPIs", titlesize=11f0)

    hidedecorations!(ax_kpi; label=false, title=false)
    text!(ax_kpi, 0.05, 0.95;
        text=text_content,
        space=:relative,
        align=(:left, :top),
        fontsize=10f0,
        font="DejaVu Sans Mono")

    rowsize!(side, 2, Relative(0.35))
    return nothing
end
