# API Reference

## Types

```@docs
WaferSpec
DieGrid
WaferField
WaferDie
WaferData
WaferVectorData
FieldedData
AveragedField
FieldProfile
ArrowScale
ColorScale
AbstractKPI
KPIMean
KPISigma
KPIMax
KPIMin
KPIMedian
KPIMeanPlus3Sigma
KPIMeanMinus3Sigma
KPIP99
```

## Color scaling

```@docs
normalize
```

## KPI interface

```@docs
DEFAULT_KPIS
name
compute
format_value
```

## Geometry

```@docs
wafer_polygon
inside_wafer
field_bounds
die_bounds
field_grid
```

## Vector field analysis

```@docs
divergence
vorticity
```

## Field analysis

```@docs
fielded
assign_to_fields
is_full_field
is_full_die
full_fields
partial_fields
full_dies
filter_full
serpentine_numbers
stack_fields
field_average_profiles
field_kpis
average_wafers
arrow_scale
arrow_scale_from
```

## Figure layout

```@docs
wafer_figure
wafer_cfd_figure
wafer_facet
add_colorbar!
add_kpi_panel!
add_exclusion_ring!
add_ring_legend!
add_image_overlay!
add_logo!
add_watermark!
add_scale_arrow!
plot_averaged_field
field_facet
draw_field_numbers!
```

## Scalar plots

```@docs
waferscatter
waferscatter!
waferheatmap
waferheatmap!
wafercontour
wafercontour!
```

## Vector plots

```@docs
waferarrows
waferarrows!
waferstreamlines
waferstreamlines!
waferdivergence
waferdivergence!
wafervorticity
wafervorticity!
```
