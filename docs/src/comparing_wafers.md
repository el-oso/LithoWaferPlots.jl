# Comparing wafers across a lot

Most wafer analysis is *comparative*: you have a lot of wafers and want to see, at a glance,
how their spatial signatures differ — which wafers share a distortion fingerprint, which one
is the outlier, whether a tool left a systematic interfield pattern across the lot.

This page builds a 12-wafer lot, gives each wafer a per-exposure-field distortion vector (its
*fingerprint*), and lays the lot out as small multiples for side-by-side comparison. It uses
only LithoWaferPlots and a Makie backend — no extra plotting packages.

## A per-field fingerprint from Zernike modes

We sample **one vector per exposure field** — the *interfield* signature an engineer reads off
a registration map. Each field's vector is built from the first five
[Fringe Zernike](https://en.wikipedia.org/wiki/Zernike_polynomials) modes — piston, x-tilt,
y-tilt, defocus, astigmatism — with per-wafer coefficients standing in for the systematic
error each wafer picked up. The Zernike helper is just example data generation, so it lives
inline rather than in the package.

```@example fingerprint
using LithoWaferPlots, CairoMakie
using Random: seed!

wafer = WaferSpec(300.0)
R = wafer.diameter_mm / 2

# One sample per exposure field → the interfield fingerprint.
fw, fh = 26.0, 33.0
centers = [((ci - 0.5) * fw, (ri - 5) * fh) for ri in 1:9, ci in -5:6]
fields = field_grid(centers, (fw, fh); wafer = wafer)
fx = [f.x_center_mm for f in fields]
fy = [f.y_center_mm for f in fields]

# Gradients of the first five Fringe Zernike terms on normalized coords (u,v) = (x,y)/R:
# Z1 piston, Z2 x-tilt, Z3 y-tilt, Z4 defocus (2(u²+v²)-1), Z5 astigmatism (u²-v²).
zern_grad(u, v) = ((0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (4u, 4v), (2u, -2v))

# 12 wafers, each a deterministic coefficient fingerprint (seeded). Per-mode amplitudes
# in nm; piston (index 1) is ignored since it carries no in-plane vector.
seed!(2026)
scales = (0.0, 10.0, 10.0, 6.0, 8.0)
coeffs = [ntuple(k -> scales[k] * randn(), 5) for _ in 1:12]

length(coeffs), length(fx)   # 12 wafers, this many fields each
```

## Two ways to turn coefficients into a vector field

The same five numbers can be read two ways. Both are shown below; pick whichever matches how
you think about the data — they produce visibly different fingerprints from identical coefficients.

```@example fingerprint
# A — wavefront slope: arrows = ∇W of W = Σ cᵢ Zᵢ (a curl-free slope field, nm).
# Defocus → radial, astigmatism → saddle, tilt → uniform shift.
function fingerprint_gradient(c)
    vx = similar(fx); vy = similar(fy)
    for i in eachindex(fx)
        u, v = fx[i] / R, fy[i] / R
        g = zern_grad(u, v)
        vx[i] = sum(c[k] * g[k][1] for k in 1:5)
        vy[i] = sum(c[k] * g[k][2] for k in 1:5)
    end
    WaferVectorData((x = fx, y = fy, vx = vx, vy = vy), wafer)
end

# B — named overlay terms read straight off the coefficients (nm):
# translation (tilt) + magnification (defocus) + astigmatic shear.
function fingerprint_overlay(c)
    vx = similar(fx); vy = similar(fy)
    for i in eachindex(fx)
        u, v = fx[i] / R, fy[i] / R
        vx[i] = c[2] + c[4] * u + c[5] * u
        vy[i] = c[3] + c[4] * v - c[5] * v
    end
    WaferVectorData((x = fx, y = fy, vx = vx, vy = vy), wafer)
end
nothing # hide
```

## Layout option 1 — one 3×4 grid

`waferarrows!` draws into any `Axis`, so a lot grid is a plain loop over a `GridLayout`. Fixed
square panels (`width`/`height`) plus `resize_to_layout!` give tight, equally-scaled small
multiples; pinning identical `limits!` on every panel keeps the wafers the same size and makes
the arrow lengths directly comparable. The `40 nm` scale arrow sits in the corner of the last
panel — see [The scale arrow](@ref) below.

```@example fingerprint
const LS = 0.5     # nm → mm for the arrows (shared by every panel and the scale arrow)
const REF = 40.0   # nm reference length for the scale arrow

function fingerprint_grid(builder, cs, rows, cols, idx; title)
    fig = Figure()
    gl = fig[1, 1] = GridLayout()
    axs = Axis[]
    for (panel, k) in enumerate(idx)
        r, c = fldmod1(panel, cols)
        ax = Axis(gl[r, c]; aspect = DataAspect(), width = 160, height = 160,
                  title = "Wafer " * lpad(k, 2, '0'), titlesize = 11)
        hidedecorations!(ax); hidespines!(ax)
        limits!(ax, -165, 165, -165, 165)
        waferarrows!(ax, builder(cs[k]); lengthscale = LS, arrowcolor = :steelblue,
                     draw_fields = false)
        push!(axs, ax)
    end
    add_scale_arrow!(axs[end], REF * LS; label = "$(Int(REF)) nm", position = :rb)
    colgap!(gl, 6); rowgap!(gl, 10)
    Label(fig[0, 1], title; fontsize = 15, font = :bold, tellwidth = false)
    resize_to_layout!(fig)
    fig
end

fingerprint_grid(fingerprint_gradient, coeffs, 3, 4, 1:12;
                 title = "Wavefront-slope fingerprint (∇W)")
```

The same lot, read as overlay terms (field meaning **B**):

```@example fingerprint
fingerprint_grid(fingerprint_overlay, coeffs, 3, 4, 1:12;
                 title = "Overlay-term fingerprint")
```

## Layout option 2 — two 2×3 figures

For a larger per-wafer view — two slides, or comparing half-lots — split the twelve into two
2×3 figures by passing a different `idx` range to the same function:

```@example fingerprint
fingerprint_grid(fingerprint_gradient, coeffs, 2, 3, 1:6; title = "Wafers 1–6")
```

```@example fingerprint
fingerprint_grid(fingerprint_gradient, coeffs, 2, 3, 7:12; title = "Wafers 7–12")
```

## The scale arrow

Arrows are drawn in data (mm) coordinates scaled by `lengthscale`, so a vector of magnitude
`m` nm appears `m * lengthscale` mm long. [`add_scale_arrow!`](@ref) draws a reference of
`REF * LS` mm labelled `"40 nm"`; because every panel shares the same `lengthscale`, that one
reference calibrates all of them. Drop it into any wafer `Axis`:

```julia
add_scale_arrow!(ax, 40.0 * LS; label = "40 nm", position = :rb)
```
