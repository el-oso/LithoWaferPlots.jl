
# API Reference {#API-Reference}

## Types {#Types}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.WaferSpec' href='#LithoWaferPlots.WaferSpec'><span class="jlbinding">LithoWaferPlots.WaferSpec</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
WaferSpec(diameter_mm, notch_angle_deg, notch_depth_mm, edge_exclusion_mm)
```


Physical parameters of a semiconductor wafer.

Coordinate system follows SEMI M20: origin at wafer centre, units in mm, +x right, +y up. Notch position convention: 270° = bottom (6 o'clock), per Artwork Systems glossary.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.DieGrid' href='#LithoWaferPlots.DieGrid'><span class="jlbinding">LithoWaferPlots.DieGrid</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
DieGrid(origin_x_mm, origin_y_mm, die_width_mm, die_height_mm)
```


Uniform die grid layout for converting (col, row) indices to mm coordinates.

Die (1, 1) centre is at (origin_x_mm, origin_y_mm) relative to wafer centre. Column index increases in +x direction, row index increases in +y direction, consistent with SEMI M21 Cartesian addressing.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.WaferField' href='#LithoWaferPlots.WaferField'><span class="jlbinding">LithoWaferPlots.WaferField</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
WaferField(x_center_mm, y_center_mm, width_mm, height_mm, col_idx, row_idx)
```


Rectangular exposure field on the wafer. `col_idx` and `row_idx` follow SEMI M21 Cartesian grid addressing relative to the wafer centre.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.WaferDie' href='#LithoWaferPlots.WaferDie'><span class="jlbinding">LithoWaferPlots.WaferDie</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
WaferDie(field, col_idx, row_idx)
```


A single die within a `WaferField`. Indices are 1-based within the field.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.WaferData' href='#LithoWaferPlots.WaferData'><span class="jlbinding">LithoWaferPlots.WaferData</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
WaferData{T}(x, y, values, wafer, fields)
```


Scalar measurements at spatial positions on a wafer. Coordinates are in mm from wafer centre (SEMI M20 convention). `fields` may be empty.

Construct via `WaferData(table, wafer)` (mm coords) or `WaferData(table, grid, wafer)` (die indices).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.WaferVectorData' href='#LithoWaferPlots.WaferVectorData'><span class="jlbinding">LithoWaferPlots.WaferVectorData</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
WaferVectorData(x, y, vx, vy, wafer, fields)
```


Vector-field measurements at spatial positions on a wafer. `vx`/`vy` are the x- and y-components of the vector at each (x, y) point.

Construct via `WaferVectorData(table, wafer)` or `WaferVectorData(table, grid, wafer)`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.ColorScale' href='#LithoWaferPlots.ColorScale'><span class="jlbinding">LithoWaferPlots.ColorScale</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
ColorScale(values; percentile_clip=0.0)
```


Build a `ColorScale` from data. If `percentile_clip > 0`, the min/max are taken at the given percentile (e.g. 0.02 → 2nd–98th percentile) to reduce outlier influence.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.AbstractKPI' href='#LithoWaferPlots.AbstractKPI'><span class="jlbinding">LithoWaferPlots.AbstractKPI</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
AbstractKPI
```


Interface contract for key performance indicators displayed in the KPI panel.

Mandatory methods:
- `name(kpi) :: String` — short display label
  
- `compute(kpi, values) :: Real` — compute the KPI from a vector of measurements
  

Optional methods:
- `description(kpi) :: String` — tooltip / longer description
  
- `format_value(kpi, v) :: String` — how to render the numeric result (default: 6 sig figs)
  

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPIMean' href='#LithoWaferPlots.KPIMean'><span class="jlbinding">LithoWaferPlots.KPIMean</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Arithmetic mean of the measurement values.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPISigma' href='#LithoWaferPlots.KPISigma'><span class="jlbinding">LithoWaferPlots.KPISigma</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Sample standard deviation of the measurement values.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPIMax' href='#LithoWaferPlots.KPIMax'><span class="jlbinding">LithoWaferPlots.KPIMax</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Maximum measurement value.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPIMin' href='#LithoWaferPlots.KPIMin'><span class="jlbinding">LithoWaferPlots.KPIMin</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Minimum measurement value.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPIMedian' href='#LithoWaferPlots.KPIMedian'><span class="jlbinding">LithoWaferPlots.KPIMedian</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Median of the measurement values.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPIMeanPlus3Sigma' href='#LithoWaferPlots.KPIMeanPlus3Sigma'><span class="jlbinding">LithoWaferPlots.KPIMeanPlus3Sigma</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Mean plus three standard deviations (upper process limit).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPIMeanMinus3Sigma' href='#LithoWaferPlots.KPIMeanMinus3Sigma'><span class="jlbinding">LithoWaferPlots.KPIMeanMinus3Sigma</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Mean minus three standard deviations (lower process limit).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.KPIP99' href='#LithoWaferPlots.KPIP99'><span class="jlbinding">LithoWaferPlots.KPIP99</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



99th percentile of the measurement values.

</details>


## Color scaling {#Color-scaling}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.normalize' href='#LithoWaferPlots.normalize'><span class="jlbinding">LithoWaferPlots.normalize</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
normalize(cs::ColorScale, v) -> Float64 in [0, 1]
```


</details>


## KPI interface {#KPI-interface}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.DEFAULT_KPIS' href='#LithoWaferPlots.DEFAULT_KPIS'><span class="jlbinding">LithoWaferPlots.DEFAULT_KPIS</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



```julia
DEFAULT_KPIS
```


KPIs shown when the user does not supply a custom list.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.name' href='#LithoWaferPlots.name'><span class="jlbinding">LithoWaferPlots.name</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
name(kpi::AbstractKPI) -> String
```


Return the short display label for this KPI (shown in the KPI panel).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.compute' href='#LithoWaferPlots.compute'><span class="jlbinding">LithoWaferPlots.compute</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
compute(kpi::AbstractKPI, values::AbstractVector{<:Real}) -> Real
```


Compute the KPI scalar from a vector of finite measurement values.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.format_value' href='#LithoWaferPlots.format_value'><span class="jlbinding">LithoWaferPlots.format_value</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
format_value(kpi::AbstractKPI, v::Real) -> String
```


Default formatter: 6 significant figures. Override in your `AbstractKPI` subtype via the optional `format_value` method.

</details>


## Geometry {#Geometry}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafer_polygon' href='#LithoWaferPlots.wafer_polygon'><span class="jlbinding">LithoWaferPlots.wafer_polygon</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafer_polygon(spec::WaferSpec; n::Int=256) -> Vector{Tuple{Float64,Float64}}
```


Return a closed polygon approximating the wafer boundary with a V-notch.

The circle is sampled at `n` points. Three extra vertices replace the arc segment nearest `notch_angle_deg` to form a V-notch indented by `notch_depth_mm`.

Reference: notch geometry derived from cap1tan/wafermap (MIT) and Artwork Systems wafer map glossary (https://www.artwork.com/package/wmapconvert/).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.inside_wafer' href='#LithoWaferPlots.inside_wafer'><span class="jlbinding">LithoWaferPlots.inside_wafer</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
inside_wafer(x, y, spec::WaferSpec) -> BitVector
```


Return a mask that is `true` for points within the active wafer area (radius minus edge exclusion).

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.field_bounds' href='#LithoWaferPlots.field_bounds'><span class="jlbinding">LithoWaferPlots.field_bounds</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
field_bounds(f::WaferField) -> (x_min, x_max, y_min, y_max)
```


Return the axis-aligned bounding box of a `WaferField` in mm.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.die_bounds' href='#LithoWaferPlots.die_bounds'><span class="jlbinding">LithoWaferPlots.die_bounds</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
die_bounds(d::WaferDie) -> (x_min, x_max, y_min, y_max)
```


Return the axis-aligned bounding box of a `WaferDie` in mm.

</details>


## Vector field analysis {#Vector-field-analysis}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.divergence' href='#LithoWaferPlots.divergence'><span class="jlbinding">LithoWaferPlots.divergence</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
divergence(data::WaferVectorData; grid_n::Int=256) -> WaferData{Float64}
```


Compute ∂vx/∂x + ∂vy/∂y from scattered vector field data. Returns a `WaferData` suitable for display as a scalar heatmap.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.vorticity' href='#LithoWaferPlots.vorticity'><span class="jlbinding">LithoWaferPlots.vorticity</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
vorticity(data::WaferVectorData; grid_n::Int=256) -> WaferData{Float64}
```


Compute ∂vy/∂x - ∂vx/∂y (z-component of curl) from scattered vector field data. Returns a `WaferData` suitable for display as a scalar heatmap.

</details>


## Figure layout {#Figure-layout}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafer_figure' href='#LithoWaferPlots.wafer_figure'><span class="jlbinding">LithoWaferPlots.wafer_figure</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafer_figure(; resolution=(900,650), kwargs...) -> (Figure, Axis, GridLayout)
```


Create a Figure with the standard wafer layout: main wafer Axis on the left, side panel (colorbar + KPI panel) on the right.

Requires a Makie backend: `using CairoMakie` or `using GLMakie`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafer_cfd_figure' href='#LithoWaferPlots.wafer_cfd_figure'><span class="jlbinding">LithoWaferPlots.wafer_cfd_figure</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafer_cfd_figure(vdata::WaferVectorData; scalar=:divergence, vector=:streamlines, kwargs...)
```


Create a combined CFD plot: scalar background (divergence or vorticity) with a streamline or arrow overlay in one call. Returns `(fig, ax, side)`.

Keywords:
- `scalar`: `:divergence` (default) or `:vorticity`
  
- `vector`: `:streamlines` (default), `:arrows`, or `:none`
  
- `colormap`: override auto colormap (`:RdBu` for divergence, `Reverse(:RdBu)` for vorticity)
  
- `scalar_label`: colorbar label (auto if omitted)
  
- `streamline_color`: color of streamlines (default `:white`)
  
- `n_seeds`, `max_steps`: streamline trace parameters
  
- `arrowcolor`: arrow color when `vector=:arrows`
  

Requires a Makie backend: `using CairoMakie` or `using GLMakie`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafer_facet' href='#LithoWaferPlots.wafer_facet'><span class="jlbinding">LithoWaferPlots.wafer_facet</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafer_facet(table, wafer::WaferSpec; by, kwargs...) -> Figure
```


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

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.add_colorbar!' href='#LithoWaferPlots.add_colorbar!'><span class="jlbinding">LithoWaferPlots.add_colorbar!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
add_colorbar!(side, plot_obj; label="", kwargs...)
```


Add a `Colorbar` to the top slot of the side panel returned by `wafer_figure`.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.add_kpi_panel!' href='#LithoWaferPlots.add_kpi_panel!'><span class="jlbinding">LithoWaferPlots.add_kpi_panel!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
add_kpi_panel!(side, data::WaferData; kpis=DEFAULT_KPIS)
```


Compute and display KPIs in the bottom slot of the side panel. Pass a custom `kpis` vector of `AbstractKPI` objects to override the defaults.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.add_exclusion_ring!' href='#LithoWaferPlots.add_exclusion_ring!'><span class="jlbinding">LithoWaferPlots.add_exclusion_ring!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
add_exclusion_ring!(ax, wafer::WaferSpec; mm_to_edge, label="", kwargs...)
```


Draw a dashed circle at `mm_to_edge` mm from the wafer edge. Composes with any recipe already on `ax` — call after the primary plot.

Keywords:
- `mm_to_edge::Real`: distance from the wafer edge in mm (required)
  
- `label::String`: legend entry; empty string = no legend entry
  
- `color`: ring colour (default `:red`)
  
- `linewidth`: line width (default `1.0f0`)
  
- `linestyle`: `:dash` (default), `:dot`, `:dashdot`, etc.
  
- `dim_outside::Bool`: overlay a semi-transparent fill between the ring and the wafer boundary (default `false`)
  
- `dim_color`: dim overlay colour (default `:black`)
  
- `dim_alpha::Real`: dim overlay opacity 0–1 (default `0.35`)
  

Call multiple times for several rings. Follow with `add_ring_legend!(ax)` to show labels.

Requires a Makie backend.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.add_ring_legend!' href='#LithoWaferPlots.add_ring_legend!'><span class="jlbinding">LithoWaferPlots.add_ring_legend!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
add_ring_legend!(ax; position=:rt, framevisible=false, kwargs...)
```


Show a legend on `ax` collecting all labeled elements (e.g., exclusion rings). Thin wrapper around Makie's `axislegend`.

Requires a Makie backend.

</details>


## Scalar plots {#Scalar-plots}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferscatter' href='#LithoWaferPlots.waferscatter'><span class="jlbinding">LithoWaferPlots.waferscatter</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferscatter(data::WaferData; kwargs...) -> (Figure, Axis, plot)
waferscatter!(ax, data::WaferData; kwargs...) -> plot
```


Scatter plot of wafer data with auto colormap and wafer boundary overlay.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferscatter!' href='#LithoWaferPlots.waferscatter!'><span class="jlbinding">LithoWaferPlots.waferscatter!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferscatter(data::WaferData; kwargs...) -> (Figure, Axis, plot)
waferscatter!(ax, data::WaferData; kwargs...) -> plot
```


Scatter plot of wafer data with auto colormap and wafer boundary overlay.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferheatmap' href='#LithoWaferPlots.waferheatmap'><span class="jlbinding">LithoWaferPlots.waferheatmap</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferheatmap(data::WaferData; kwargs...) -> (Figure, Axis, plot)
waferheatmap!(ax, data::WaferData; kwargs...) -> plot
```


Heatmap-style plot using rectangular scatter markers. Use `percentile_clip` to reduce outlier influence on the color scale.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferheatmap!' href='#LithoWaferPlots.waferheatmap!'><span class="jlbinding">LithoWaferPlots.waferheatmap!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferheatmap(data::WaferData; kwargs...) -> (Figure, Axis, plot)
waferheatmap!(ax, data::WaferData; kwargs...) -> plot
```


Heatmap-style plot using rectangular scatter markers. Use `percentile_clip` to reduce outlier influence on the color scale.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafercontour' href='#LithoWaferPlots.wafercontour'><span class="jlbinding">LithoWaferPlots.wafercontour</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafercontour(data::WaferData; levels=10, grid_n=256, kwargs...) -> (Figure, Axis, plot)
wafercontour!(ax, data::WaferData; levels=10, grid_n=256, kwargs...) -> plot
```


Contour plot. Data is interpolated to a regular `grid_n×grid_n` grid first.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafercontour!' href='#LithoWaferPlots.wafercontour!'><span class="jlbinding">LithoWaferPlots.wafercontour!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafercontour(data::WaferData; levels=10, grid_n=256, kwargs...) -> (Figure, Axis, plot)
wafercontour!(ax, data::WaferData; levels=10, grid_n=256, kwargs...) -> plot
```


Contour plot. Data is interpolated to a regular `grid_n×grid_n` grid first.

</details>


## Vector plots {#Vector-plots}
<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferarrows' href='#LithoWaferPlots.waferarrows'><span class="jlbinding">LithoWaferPlots.waferarrows</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferarrows(data::WaferVectorData; max_arrows=20_000, kwargs...) -> (Figure, Axis, plot)
waferarrows!(ax, data::WaferVectorData; max_arrows=20_000, kwargs...) -> plot
```


Arrow plot of vector field. Subsampled to `max_arrows` for readability.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferarrows!' href='#LithoWaferPlots.waferarrows!'><span class="jlbinding">LithoWaferPlots.waferarrows!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferarrows(data::WaferVectorData; max_arrows=20_000, kwargs...) -> (Figure, Axis, plot)
waferarrows!(ax, data::WaferVectorData; max_arrows=20_000, kwargs...) -> plot
```


Arrow plot of vector field. Subsampled to `max_arrows` for readability.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferstreamlines' href='#LithoWaferPlots.waferstreamlines'><span class="jlbinding">LithoWaferPlots.waferstreamlines</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferstreamlines(data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> (Figure, Axis, plot)
waferstreamlines!(ax, data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> plot
```


Streamline plot via RK4 integration from a uniform seed grid.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferstreamlines!' href='#LithoWaferPlots.waferstreamlines!'><span class="jlbinding">LithoWaferPlots.waferstreamlines!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferstreamlines(data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> (Figure, Axis, plot)
waferstreamlines!(ax, data::WaferVectorData; n_seeds=20, max_steps=300, kwargs...) -> plot
```


Streamline plot via RK4 integration from a uniform seed grid.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferdivergence' href='#LithoWaferPlots.waferdivergence'><span class="jlbinding">LithoWaferPlots.waferdivergence</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferdivergence(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
waferdivergence!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot
```


Divergence (∂vx/∂x + ∂vy/∂y) of the vector field, displayed as a scalar heatmap.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.waferdivergence!' href='#LithoWaferPlots.waferdivergence!'><span class="jlbinding">LithoWaferPlots.waferdivergence!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
waferdivergence(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
waferdivergence!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot
```


Divergence (∂vx/∂x + ∂vy/∂y) of the vector field, displayed as a scalar heatmap.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafervorticity' href='#LithoWaferPlots.wafervorticity'><span class="jlbinding">LithoWaferPlots.wafervorticity</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafervorticity(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
wafervorticity!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot
```


Vorticity (∂vy/∂x − ∂vx/∂y) of the vector field, displayed as a scalar heatmap.

</details>

<details class='jldocstring custom-block' open>
<summary><a id='LithoWaferPlots.wafervorticity!' href='#LithoWaferPlots.wafervorticity!'><span class="jlbinding">LithoWaferPlots.wafervorticity!</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
wafervorticity(data::WaferVectorData; grid_n=256, kwargs...) -> (Figure, Axis, plot)
wafervorticity!(ax, data::WaferVectorData; grid_n=256, kwargs...) -> plot
```


Vorticity (∂vy/∂x − ∂vx/∂y) of the vector field, displayed as a scalar heatmap.

</details>

