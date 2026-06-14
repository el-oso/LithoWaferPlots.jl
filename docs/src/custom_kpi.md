# Custom KPIs

The side panel produced by `add_kpi_panel!` is driven by a vector of `AbstractKPI`
objects. Any struct that implements the two mandatory methods — `name` and `compute` —
qualifies.

## Minimal example: Range

```julia
using LithoWaferPlots
using TypeContracts: implements

struct KPIRange <: AbstractKPI end

LithoWaferPlots.name(::KPIRange) = "Range"

function LithoWaferPlots.compute(::KPIRange, v::AbstractVector{<:Real})::Float64
    maximum(v) - minimum(v)
end

@assert implements(KPIRange, AbstractKPI)   # verify at load time
```

Pass it alongside the built-in defaults:

```julia
using CairoMakie

my_kpis = [DEFAULT_KPIS..., KPIRange()]

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma)
add_colorbar!(side, p; label = "Thickness (nm)")
add_kpi_panel!(side, data; kpis = my_kpis)
```

Or replace the defaults entirely:

```julia
add_kpi_panel!(side, data; kpis = [KPIMean(), KPISigma(), KPIRange()])
```

## Custom formatting: Non-Uniformity (NU)

Process engineers often report thickness uniformity as
**NU% = σ / mean × 100**. The optional `format_value` method controls
how the computed number is rendered in the panel.

```julia
using Printf

struct KPINonUniformity <: AbstractKPI end

LithoWaferPlots.name(::KPINonUniformity) = "NU%"

function LithoWaferPlots.compute(::KPINonUniformity, v::AbstractVector{<:Real})::Float64
    100.0 * std(v) / mean(v)
end

# Format as "1.23 %" instead of the default 6-significant-figure string.
function LithoWaferPlots.format_value(::KPINonUniformity, v::Real)::String
    @sprintf("%.2f", v) * " %"
end

@assert implements(KPINonUniformity, AbstractKPI)
```

Full plot:

```julia
using LithoWaferPlots, CairoMakie, Printf, Statistics
using TypeContracts: implements

wafer = WaferSpec(300.0)
data  = WaferData((x = x, y = y, value = thickness), wafer)

fab_kpis = [KPIMean(), KPISigma(), KPINonUniformity(), KPIRange()]

fig, ax, side = wafer_figure()
p = waferheatmap!(ax, data; colormap = :plasma)
add_colorbar!(side, p; label = "Thickness (nm)")
add_kpi_panel!(side, data; kpis = fab_kpis)

save("thickness.png", fig)
```

## Contract reference

| Method | Required | Signature |
|---|---|---|
| `name` | yes | `(::Self) -> String` |
| `compute` | yes | `(::Self, ::AbstractVector{<:Real}) -> Real` |
| `format_value` | no | `(::Self, ::Real) -> String` — default: 6 significant figures |
| `description` | no | `(::Self) -> String` — for future tooltip support |

Rules:
- `compute` receives only **finite, inside-wafer** values (NaN / Inf already removed).
- `format_value` receives whatever `compute` returned; return a plain `String`.
- Extend `LithoWaferPlots.name` and `LithoWaferPlots.compute` (not bare `name`/`compute`)
  to avoid method ambiguity with other packages.
