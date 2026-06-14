"""
TypeContracts.jl interface definitions for LithoWaferPlots.

Users implement `AbstractKPI` to add custom metrics to the KPI panel.
"""

"""
    AbstractKPI

Interface contract for key performance indicators displayed in the KPI panel.

Mandatory methods:
- `name(kpi) :: String` — short display label
- `compute(kpi, values) :: Real` — compute the KPI from a vector of measurements

Optional methods:
- `description(kpi) :: String` — tooltip / longer description
- `format_value(kpi, v) :: String` — how to render the numeric result (default: 6 sig figs)
"""
abstract type AbstractKPI end

@contract AbstractKPI begin
    name(::Self) :: String
    compute(::Self, values::AbstractVector{<:Real}) :: Real
    :optional
    description(::Self) :: String
    format_value(::Self, v::Real) :: String
end
