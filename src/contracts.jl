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
- `format_value(kpi, v) :: String` — how to render the numeric result (default: 6 sig figs).
  `add_kpi_panel!(...; sigdigits=…)` rounds the value to `sigdigits` *before* calling this, so
  a custom override is always honoured (never bypassed) and still respects the chosen precision.
"""
abstract type AbstractKPI end

@contract AbstractKPI begin
    name(::Self)::String
    compute(::Self, values::AbstractVector{<:Real})::Real
    :optional
    description(::Self)::String
    format_value(::Self, v::Real)::String
end

"""
    name(kpi::AbstractKPI) -> String

Return the short display label for this KPI (shown in the KPI panel).
"""
function name end

"""
    compute(kpi::AbstractKPI, values::AbstractVector{<:Real}) -> Real

Compute the KPI scalar from a vector of finite measurement values.
"""
function compute end
