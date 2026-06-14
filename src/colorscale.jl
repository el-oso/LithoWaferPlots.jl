"""
Color scale helpers — backend-independent.

Maps data values to [0,1] for use with any colormap.
"""

struct ColorScale
    vmin::Float64
    vmax::Float64
end

"""
    ColorScale(values; percentile_clip=0.0)

Build a `ColorScale` from data. If `percentile_clip > 0`, the min/max are taken at
the given percentile (e.g. 0.02 → 2nd–98th percentile) to reduce outlier influence.
"""
function ColorScale(values::AbstractVector{<:Real}; percentile_clip::Float64 = 0.0)
    if percentile_clip > 0.0
        lo = quantile(values, percentile_clip)
        hi = quantile(values, 1.0 - percentile_clip)
    else
        lo = Float64(minimum(values))
        hi = Float64(maximum(values))
    end
    lo == hi && (hi = lo + 1.0)  # avoid degenerate range
    return ColorScale(lo, hi)
end

"""
    normalize(cs::ColorScale, v) -> Float64 in [0, 1]
"""
normalize(cs::ColorScale, v::Real) = clamp((Float64(v) - cs.vmin) / (cs.vmax - cs.vmin), 0.0, 1.0)

normalize(cs::ColorScale, v::AbstractVector{<:Real}) = normalize.(Ref(cs), v)
