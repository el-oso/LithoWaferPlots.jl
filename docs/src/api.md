# API Reference

## Types

```@docs
WaferSpec
DieGrid
WaferField
WaferDie
WaferData
WaferVectorData
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
```

## Vector field analysis

```@docs
divergence
vorticity
```

## Figure layout

```@docs
wafer_figure
wafer_cfd_figure
add_colorbar!
add_kpi_panel!
add_exclusion_ring!
add_ring_legend!
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
