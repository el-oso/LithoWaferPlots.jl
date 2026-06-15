# CLAUDE.md

## Commands

```julia
# Run all tests
julia --project=test test/runtests.jl

# Run a single test item by name
julia --project=test -e 'using LithoWaferPlots, ReTestItems; runtests(LithoWaferPlots; name=r"WaferSpec")'

# Skip rendering tests (headless CI)
julia --project=test -e 'using LithoWaferPlots, ReTestItems; runtests(LithoWaferPlots; tags=[:rendering] |> exclude)'

# Generate doc images (requires CairoMakie, AlgebraOfGraphics, DataFrames in docs env)
julia --project=docs docs/generate_examples.jl

# Build docs
julia --project=docs docs/make.jl

# Run PkgBenchmark suite
julia --project=benchmarks -e 'using PkgBenchmark, LithoWaferPlots; export_markdown(stdout, benchmarkpkg(LithoWaferPlots))'

# Run legacy scripts (compute: headless-safe; render: requires GLMakie + display)
julia --project=benchmarks benchmarks/compute_bench.jl
julia --project=benchmarks benchmarks/render_bench.jl
```

## Architecture

`src/LithoWaferPlots.jl` is the module root (exports + includes only).

### Core (`src/`)

| File | Contents |
|---|---|
| `types.jl` | `WaferSpec`, `DieGrid`, `WaferField`, `WaferDie`, `WaferData`, `WaferVectorData` |
| `geometry.jl` | `wafer_polygon`, `inside_wafer`, `field_bounds`, `die_bounds` |
| `input.jl` | Tables.jl constructors for mm-coord and die-index modes |
| `contracts.jl` | `AbstractKPI` contract via TypeContracts.jl |
| `kpi.jl` | Built-in KPI structs; `DEFAULT_KPIS`; `format_value` fallback |
| `colorscale.jl` | `ColorScale`, `normalize` |
| `vectorfields.jl` | `divergence`, `vorticity` (interpolate → grid → finite diff) |
| `plot_interface.jl` | Stub functions that delegate to the Makie extension via `Base.get_extension` |

Makie rendering lives entirely in `ext/LithoWaferPlotsMakieExt/` — loaded only
when Makie is in the environment. No Makie symbols in `src/`.

### Makie extension (`ext/LithoWaferPlotsMakieExt/`)

| File | Contents |
|---|---|
| `LithoWaferPlotsMakieExt.jl` | Module root; `using Makie`, `using Tables`; all exports |
| `wafer_shape.jl` | `draw_wafer_boundary!`, `draw_fields!`, `_draw_ring!`, `_draw_dim_annulus!` |
| `streamlines.jl` | RK4 streamline tracer used by `WaferStreamlines` |
| `recipes_scalar.jl` | `WaferScatter`, `WaferHeatmap` (scatter + image modes), `WaferContour` |
| `recipes_vector.jl` | `WaferArrows`, `WaferStreamlines`, `WaferDivergence`, `WaferVorticity` |
| `layout.jl` | `wafer_figure`, `wafer_cfd_figure`, `wafer_facet`, `add_colorbar!`, `add_kpi_panel!`, `add_exclusion_ring!`, `add_ring_legend!` |

### Stub delegation pattern

Every public plotting function in `src/plot_interface.jl` follows this pattern:

```julia
function my_fn(args...; kwargs...)
    ext = Base.get_extension(LithoWaferPlots, :LithoWaferPlotsMakieExt)
    ext === nothing && error("Load a Makie backend first: using CairoMakie")
    return ext.my_fn(args...; kwargs...)
end
```

Export the stub in `src/LithoWaferPlots.jl` AND the implementation in
`LithoWaferPlotsMakieExt.jl`. Both exports are required.

## Key design decisions

### `draw_boundary` / `draw_fields` attributes
Every recipe has `draw_boundary = true` and `draw_fields = true` boolean attributes.
Set them to `false` on overlay recipes to avoid drawing the wafer boundary twice
(e.g., `waferstreamlines!(ax, vdata; draw_boundary=false, draw_fields=false)` when
composing on top of `waferdivergence!`). `wafer_cfd_figure` does this automatically.

### `WaferHeatmap` image mode
For datasets above 5 000 points `WaferHeatmap` switches to `image!` (GPU texture path)
automatically unless `imagemode=:scatter` is forced. `wafer_facet` always forces
`imagemode=:scatter` so it can override `colorrange` after plotting.

### Colorbar construction
`add_colorbar!(side, plot_obj)` finds the first `Scatter` child of `plot_obj` and
attaches a `Colorbar` to it. For image mode it reconstructs the colorrange from the
raw data. For contour mode it uses data extrema. Always use `add_colorbar!` instead
of constructing a bare `Colorbar` — it handles all three code paths.

### Exclusion rings
`add_exclusion_ring!(ax, wafer; mm_to_edge=...)` converts mm-to-edge to radius
(`r = diameter/2 - mm_to_edge`) internally. The `dim_outside=true` option draws an
annular overlay using `Makie.GeometryBasics.Polygon(outer_ccw, [inner_cw])`.
Do NOT `using GeometryBasics` directly — use `Makie.GeometryBasics.Polygon` since
GeometryBasics is a transitive dep and not declared in the extension's direct deps.

### `wafer_facet` shared colorrange
When `colorrange=(lo, hi)` is passed, `wafer_facet` forces scatter mode, then patches
each panel's Scatter child: `p.plots[scatter_idx].colorrange[] = (Float32(lo), Float32(hi))`.

### AlgebraOfGraphics compositing
AoG is a docs/example dependency only — not in the package `[deps]` or `[weakdeps]`.
Use `draw!(fig[r, c], aog_layer)` to place an AoG layer beside a LithoWaferPlots panel
in the same `Figure`. `wafer_facet` covers the spatial multi-panel use case; AoG covers
statistical views (violin, radial scatter, lot comparison).

### Time-to-first-plot / precompilation
The extension's precompile workload (bottom of `LithoWaferPlotsMakieExt.jl`, guarded by
`ccall(:jl_generating_output, …)`) must exercise **every recipe** — add new recipes to it.
Precompilation is undone by *invalidations*: never overload `Base.show(::IO, ::Type{X})` or
other broad type/print methods — they invalidate the whole pipeline and recompile seconds of
code on first plot. After dependency bumps, audit with `SnoopCompile`'s
`@snoop_invalidations` (see `docs/src/performance.md`); keep total invalidations in the tens.

## Requirements

- Never add Makie as a hard `[deps]` entry — keep it in `[weakdeps]`.
- All plot recipes must overlay the wafer boundary (circle + V-notch) automatically.
- Performance target: 300 000 points in < 0.3 s (GLMakie, median). Run benchmarks before PRs.
- Tests use `@testitem` (ReTestItems.jl). No bare `@testset`.
- Rendering tests must carry `tags=[:rendering]` and guard against headless environments.
- TypeContracts: add `@verify MyKPI` after any new `AbstractKPI` implementation.
- Run `runic -i .` from the repo root before every git commit.
- The extension must work with **all three backends**: CairoMakie, GLMakie, and WGLMakie.
  Never use backend-specific APIs in the extension code itself.
- `docs/Project.toml` includes AlgebraOfGraphics and DataFrames for example generation.
  Do not add these to the main `[deps]`.
