# Custom KPIs

The KPI panel accepts any object that satisfies the `AbstractKPI` contract.

## Implementing a custom KPI

```julia
using LithoWaferPlots
using TypeContracts: implements

struct MyRange <: AbstractKPI end

LithoWaferPlots.name(::MyRange) = "Range"
LithoWaferPlots.compute(::MyRange, v::AbstractVector{<:Real}) = maximum(v) - minimum(v)

# Optional: customise display
LithoWaferPlots.format_value(::MyRange, v::Real) = @sprintf("%.2f nm", v)

@assert implements(MyRange, AbstractKPI)  # verify at load time
```

## Using in a plot

```julia
my_kpis = [KPIMean(), KPISigma(), MyRange()]

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data)
add_colorbar!(side, p)
add_kpi_panel!(side, data; kpis=my_kpis)
display(fig)
```

## Contract reference

| Method | Required | Signature |
|---|---|---|
| `name` | yes | `name(::Self) :: String` |
| `compute` | yes | `compute(::Self, ::AbstractVector{<:Real}) :: Real` |
| `description` | no | `description(::Self) :: String` |
| `format_value` | no | `format_value(::Self, ::Real) :: String` |
