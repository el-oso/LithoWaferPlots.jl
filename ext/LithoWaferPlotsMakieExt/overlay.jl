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
