"""
Logo / watermark image overlays for wafer plots.

`add_image_overlay!` places an image at a fixed position relative to a target `Axis` or
`Figure`, keeping the image's aspect ratio (it does not distort or move with the data /
`DataAspect` / zoom). Per-pixel alpha from RGBA images is honoured and a global `opacity`
multiplier is applied on top. `add_logo!` and `add_watermark!` are thin wrappers with
convenience defaults.

The overlay is drawn into a dedicated top child `Scene` with a pixel camera, so it always
renders above the target's content; placement is `lift`ed on the scene viewport so it stays
correct on resize and for static CairoMakie saves.
"""

_target_scene(ax::Axis) = ax.scene
_target_scene(fig::Figure) = fig.scene
_target_scene(scene::Makie.Scene) = scene

# Convert any image (RGB/RGBA/Gray matrix) to RGBAf and fold the global opacity into alpha.
function _to_rgba(img::AbstractMatrix, opacity::Real)
    rgba = RGBAf.(img)
    op = Float32(clamp(opacity, 0.0, 1.0))
    op == 1.0f0 && return Matrix{RGBAf}(rgba)
    return RGBAf[RGBAf(c.r, c.g, c.b, c.alpha * op) for c in rgba]
end

_prepare_overlay_image(image::AbstractMatrix, opacity::Real) = _to_rgba(image, opacity)

function _prepare_overlay_image(path::AbstractString, opacity::Real)
    # FileIO returns the image row-major with the first row at the top; rotate so it
    # displays upright under Makie's `image!` (first index → x, second → y, origin bottom-left).
    img = rotr90(Makie.FileIO.load(path))
    return _to_rgba(img, opacity)
end

# position symbol → (horizontal, vertical) anchors in {:left,:center,:right}×{:bottom,:center,:top}
const _OVERLAY_ANCHORS = Dict(
    :lt => (:left, :top), :ct => (:center, :top), :rt => (:right, :top),
    :lc => (:left, :center), :center => (:center, :center), :rc => (:right, :center),
    :lb => (:left, :bottom), :cb => (:center, :bottom), :rb => (:right, :bottom),
)

function _overlay_origin(position, W::Float64, H::Float64, w::Float64, h::Float64, m::Float64)
    if position isa Tuple || position isa AbstractVector
        # fractional CENTRE of the image in 0..1 of the target
        fx, fy = Float64(position[1]), Float64(position[2])
        return fx * W - w / 2, fy * H - h / 2
    end
    haskey(_OVERLAY_ANCHORS, position) ||
        error("position must be one of $(sort(collect(keys(_OVERLAY_ANCHORS)))) or an (fx, fy) tuple, got :$position")
    hz, vt = _OVERLAY_ANCHORS[position]
    x0 = hz === :left ? m : hz === :right ? (W - m - w) : (W - w) / 2
    y0 = vt === :bottom ? m : vt === :top ? (H - m - h) : (H - h) / 2
    return x0, y0
end

"""
    add_image_overlay!(target, image; position=:rt, scale=0.15, margin=0.04, opacity=1.0, interpolate=true)

Overlay `image` on `target` (an `Axis` or a `Figure`) at a fixed, aspect-preserving position.

- `image`: a path to an image file (PNG with alpha, etc.) or an `AbstractMatrix` of colors
  (RGB/RGBA/Gray). A matrix is interpreted in Makie image orientation (first index → x,
  second index → y, origin bottom-left).
- `position`: one of `:lt :ct :rt :lc :center :rc :lb :cb :rb`, or an `(fx, fy)` tuple giving
  the image centre in `0..1` of the target.
- `scale`: image height as a fraction of the target height (width follows from the image
  aspect ratio).
- `margin`: padding from the edges as a fraction of the target's smaller dimension.
- `opacity`: global alpha multiplier in `0..1`, applied on top of the image's own alpha.

Returns the `image!` plot. Requires a Makie backend.
"""
function add_image_overlay!(
        target, image;
        position = :rt,
        scale::Real = 0.15,
        margin::Real = 0.04,
        opacity::Real = 1.0,
        interpolate::Bool = true,
    )
    img = _prepare_overlay_image(image, opacity)
    nx, ny = size(img, 1), size(img, 2)
    aspect = nx / ny

    parent = _target_scene(target)
    ov = Scene(parent; clear = false)
    campixel!(ov)

    geom = lift(ov.viewport) do vp
        W = Float64(vp.widths[1])
        H = Float64(vp.widths[2])
        h = Float64(scale) * H
        w = h * aspect
        m = Float64(margin) * min(W, H)
        x0, y0 = _overlay_origin(position, W, H, w, h, m)
        return (x0, y0, w, h)
    end
    xr = lift(g -> g[1] .. (g[1] + g[3]), geom)
    yr = lift(g -> g[2] .. (g[2] + g[4]), geom)

    return image!(ov, xr, yr, img; interpolate = interpolate)
end

"""
    add_logo!(target, image; position=:rt, scale=0.12, margin=0.03, opacity=1.0, kwargs...)

Place a logo image in a corner of `target` (an `Axis` or `Figure`). Convenience wrapper over
[`add_image_overlay!`](@ref) with small, corner-anchored defaults.
"""
function add_logo!(
        target, image;
        position = :rt, scale::Real = 0.12, margin::Real = 0.03, opacity::Real = 1.0, kwargs...
    )
    return add_image_overlay!(target, image; position, scale, margin, opacity, kwargs...)
end

"""
    add_watermark!(target, image; position=:center, scale=0.5, opacity=0.15, kwargs...)

Place a large, faded watermark image over `target` (an `Axis` or `Figure`). Convenience
wrapper over [`add_image_overlay!`](@ref) with centred, semi-transparent defaults.
"""
function add_watermark!(
        target, image;
        position = :center, scale::Real = 0.5, opacity::Real = 0.15, kwargs...
    )
    return add_image_overlay!(target, image; position, scale, opacity, kwargs...)
end

"""
    add_scale_arrow!(ax, length_data; label="", position=:rb, kwargs...)

Draw a horizontal reference arrow `length_data` long **in data (mm) coordinates** on a
wafer `Axis`, with `label` centred above it. Because it lives in data coordinates it
shares the `lengthscale` used by [`waferarrows!`](@ref): pass `length_data = ref *
lengthscale` and `label = "\$ref nm"` so the arrow reads as "this length = ref nm".

The arrow is anchored to a corner/edge of the axis (tracking the axis limits, so it stays
put on resize and for static saves).

Keywords:
- `label`: text drawn above the arrow (e.g. `"50 nm"`); empty = no text.
- `position`: `:lt :ct :rt :lc :center :rc :lb :cb :rb` (default `:rb`, bottom-right).
- `color`: arrow colour (default `:black`).
- `linewidth`: shaft/head width (default `1.5`).
- `head_frac`: arrowhead length as a fraction of `length_data` (default `0.25`).
- `head_angle`: half-angle of the arrowhead in radians (default `0.45`).
- `fontsize`: label font size (default `11`).
- `margin`: inset from the axis edges as a fraction of the axis span (default `0.06`).
- `textcolor`: label colour (defaults to `color`).

Requires a Makie backend.
"""
function add_scale_arrow!(
        ax, length_data::Real;
        label::AbstractString = "",
        position = :rb,
        color = :black,
        linewidth = 1.5f0,
        head_frac::Real = 0.25,
        head_angle::Real = 0.45,
        fontsize = 11.0f0,
        margin::Real = 0.06,
        textcolor = nothing,
    )
    L = Float64(length_data)
    L > 0 || error("length_data must be positive, got $L")
    haskey(_OVERLAY_ANCHORS, position) ||
        error("position must be one of $(sort(collect(keys(_OVERLAY_ANCHORS)))), got :$position")
    hz, vt = _OVERLAY_ANCHORS[position]
    tc = textcolor === nothing ? color : textcolor
    hl = head_frac * L
    hw = hl * tan(head_angle)

    # Geometry tracks the axis limits so placement is correct after layout / on resize.
    geom = lift(ax.finallimits) do lims
        xmin, ymin = lims.origin[1], lims.origin[2]
        w, h = lims.widths[1], lims.widths[2]
        mx, my = margin * w, margin * h
        x1 = hz === :left ? xmin + mx : hz === :right ? xmin + w - mx - L : xmin + (w - L) / 2
        y = vt === :bottom ? ymin + my : vt === :top ? ymin + h - my : ymin + h / 2
        (x1, x1 + L, y, h)
    end

    shaft = lift(g -> [Point2f(g[1], g[3]), Point2f(g[2], g[3])], geom)
    head = lift(
        g -> [
            Point2f(g[2] - hl, g[3] + hw), Point2f(g[2], g[3]), Point2f(g[2] - hl, g[3] - hw),
        ], geom
    )
    lines!(ax, shaft; color, linewidth)
    lines!(ax, head; color, linewidth)

    if !isempty(label)
        lpos = lift(g -> Point2f((g[1] + g[2]) / 2, g[3] + 0.012 * g[4]), geom)
        text!(ax, lpos; text = label, align = (:center, :bottom), fontsize, color = tc)
    end
    return nothing
end

"""
    add_scale_arrow!(ax, scale::ArrowScale; position=:rb, kwargs...)

Draw the reference arrow described by an `ArrowScale` (length `scale.ref_length_mm`, labelled
`scale.label`). Pairs with `waferarrows!(ax, vdata; scale)` so the reference matches the data
arrows exactly.
"""
add_scale_arrow!(ax, scale::ArrowScale; position = :rb, kwargs...) =
    add_scale_arrow!(ax, scale.ref_length_mm; label = scale.label, position, kwargs...)
