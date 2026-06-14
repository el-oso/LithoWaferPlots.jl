"""
Built-in KPI implementations.

All structs implement `AbstractKPI` and are verified at load time via `@verify`.
"""

struct KPIMean <: AbstractKPI end
name(::KPIMean) = "Mean"
compute(::KPIMean, v::AbstractVector{<:Real})::Float64 = Float64(mean(v))

struct KPISigma <: AbstractKPI end
name(::KPISigma) = "Sigma"
compute(::KPISigma, v::AbstractVector{<:Real})::Float64 = Float64(std(v))

struct KPIMax <: AbstractKPI end
name(::KPIMax) = "Max"
compute(::KPIMax, v::AbstractVector{<:Real})::Float64 = Float64(maximum(v))

struct KPIMin <: AbstractKPI end
name(::KPIMin) = "Min"
compute(::KPIMin, v::AbstractVector{<:Real})::Float64 = Float64(minimum(v))

struct KPIMedian <: AbstractKPI end
name(::KPIMedian) = "Median"
compute(::KPIMedian, v::AbstractVector{<:Real})::Float64 = Float64(median(v))

struct KPIMeanPlus3Sigma <: AbstractKPI end
name(::KPIMeanPlus3Sigma) = "Mean+3σ"
compute(::KPIMeanPlus3Sigma, v::AbstractVector{<:Real})::Float64 = Float64(mean(v)) + 3Float64(std(v))

struct KPIMeanMinus3Sigma <: AbstractKPI end
name(::KPIMeanMinus3Sigma) = "Mean-3σ"
compute(::KPIMeanMinus3Sigma, v::AbstractVector{<:Real})::Float64 = Float64(mean(v)) - 3Float64(std(v))

struct KPIP99 <: AbstractKPI end
name(::KPIP99) = "P99"
compute(::KPIP99, v::AbstractVector{<:Real})::Float64 = Float64(quantile(v, 0.99))

@verify KPIMean
@verify KPISigma
@verify KPIMax
@verify KPIMin
@verify KPIMedian
@verify KPIMeanPlus3Sigma
@verify KPIMeanMinus3Sigma
@verify KPIP99

"""
    DEFAULT_KPIS

KPIs shown when the user does not supply a custom list.
"""
const DEFAULT_KPIS = AbstractKPI[
    KPIMean(), KPISigma(), KPIMax(), KPIMin(),
    KPIMeanPlus3Sigma(), KPIMeanMinus3Sigma(),
]

"""
    format_value(kpi::AbstractKPI, v::Real) -> String

Default formatter: 6 significant figures. Override in your `AbstractKPI` subtype
via the optional `format_value` method.
"""
format_value(::AbstractKPI, v::Real) = string(round(v; sigdigits=6))
