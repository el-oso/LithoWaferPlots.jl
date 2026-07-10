"""
Built-in KPI implementations.

All structs implement `AbstractKPI` and are verified at load time via `@verify`.
"""

"Arithmetic mean of the measurement values." struct KPIMean <: AbstractKPI end
name(::KPIMean) = "Mean"
compute(::KPIMean, v::AbstractVector{<:Real})::Float64 = Float64(mean(v))

"Sample standard deviation of the measurement values." struct KPISigma <: AbstractKPI end
name(::KPISigma) = "Sigma"
compute(::KPISigma, v::AbstractVector{<:Real})::Float64 = Float64(std(v))

"Maximum measurement value." struct KPIMax <: AbstractKPI end
name(::KPIMax) = "Max"
compute(::KPIMax, v::AbstractVector{<:Real})::Float64 = Float64(maximum(v))

"Minimum measurement value." struct KPIMin <: AbstractKPI end
name(::KPIMin) = "Min"
compute(::KPIMin, v::AbstractVector{<:Real})::Float64 = Float64(minimum(v))

"Median of the measurement values." struct KPIMedian <: AbstractKPI end
name(::KPIMedian) = "Median"
compute(::KPIMedian, v::AbstractVector{<:Real})::Float64 = Float64(median(v))

"Mean plus three standard deviations (upper process limit)." struct KPIMeanPlus3Sigma <: AbstractKPI end
name(::KPIMeanPlus3Sigma) = "Mean+3σ"
compute(::KPIMeanPlus3Sigma, v::AbstractVector{<:Real})::Float64 = Float64(mean(v)) + 3Float64(std(v))

"Mean minus three standard deviations (lower process limit)." struct KPIMeanMinus3Sigma <: AbstractKPI end
name(::KPIMeanMinus3Sigma) = "Mean-3σ"
compute(::KPIMeanMinus3Sigma, v::AbstractVector{<:Real})::Float64 = Float64(mean(v)) - 3Float64(std(v))

"99th percentile of the measurement values." struct KPIP99 <: AbstractKPI end
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
    zone_kpis(data::WaferData; mm_to_edge::Real, kpis=DEFAULT_KPIS)
        -> (inner=Vector{Pair{String,Float64}}, ring=Vector{Pair{String,Float64}})

Split `data` radially at `mm_to_edge` mm from the wafer edge (same convention as
[`add_exclusion_ring!`](@ref): `boundary_radius = diameter_mm/2 - mm_to_edge`) and compute
`kpis` separately for the centre disk (`inner`, radius `<= boundary_radius`) and the outer
annulus (`ring`, radius `> boundary_radius`) — useful for comparing edge behaviour against
centre behaviour, a common wafer-metrology split. A zone with no points returns an empty
vector for that zone rather than erroring.
"""
function zone_kpis(data::WaferData; mm_to_edge::Real, kpis::AbstractVector{<:AbstractKPI} = DEFAULT_KPIS)
    r_boundary = data.wafer.diameter_mm / 2.0 - mm_to_edge
    r_boundary > 0 || error("mm_to_edge ($mm_to_edge mm) is larger than the wafer radius")
    rad = hypot.(data.x, data.y)
    inner_mask = rad .<= r_boundary
    inner_vals = filter(isfinite, data.values[inner_mask])
    ring_vals = filter(isfinite, data.values[.!inner_mask])
    inner = isempty(inner_vals) ? Pair{String, Float64}[] : [name(k) => compute(k, inner_vals) for k in kpis]
    ring = isempty(ring_vals) ? Pair{String, Float64}[] : [name(k) => compute(k, ring_vals) for k in kpis]
    return (inner = inner, ring = ring)
end

"""
    format_value(kpi::AbstractKPI, v::Real) -> String
    format_value(kpi::AbstractKPI, v::Real, sigdigits::Integer) -> String

Render a KPI value as a string. The **2-arg** form (default: 6 significant figures) is the
override point — define `format_value(::MyKPI, v::Real)` to customise rendering. The **3-arg**
form rounds `v` to `sigdigits` significant figures and then delegates to the 2-arg form, so
`add_kpi_panel!(...; sigdigits=…)` honours custom formatters instead of bypassing them.
"""
format_value(::AbstractKPI, v::Real) = string(round(v; sigdigits = 6))
format_value(kpi::AbstractKPI, v::Real, sigdigits::Integer) = format_value(kpi, round(v; sigdigits))
