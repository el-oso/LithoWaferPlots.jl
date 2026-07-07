# CLAUDE.md

## Precompilation

Both the core package and the Makie extension use `PrecompileTools.@compile_workload`
(not the raw `ccall(:jl_generating_output, ...)` guard) so `Pkg.precompile()` caches
recipe code across Makie's ComputePipeline machinery, not just our own functions —
the raw guard measurably failed to cache several ComputePipeline-generated
specializations that `@compile_workload` does cache. The core package additionally
wraps `using REPL` in `@recompile_invalidations` after `include("kpi.jl")`: loading
any Makie backend transitively loads `REPL`, which activates `TypeContracts`'
`TypeContractsREPLExt` and would otherwise invalidate the `@verify` call sites
compiled earlier in `kpi.jl`. Forcing that extension to load during our own
precompilation bakes in the post-invalidation compiled form instead of paying for
it at first-plot time.

The extension's precompile workload takes ~15-18s and reruns in full after *any*
edit under `src/` or `ext/` (source-invalidated `.ji` cache) — expected during
active development, not a bug to chase.

**Call every function in the workload as `LithoWaferPlots.<fn>(...)`, never bare
`<fn>(...)`.** Every stub-delegated function (`wafer_figure`, `waferheatmap!`, etc.)
is defined *twice*: once as the thin stub in `src/plot_interface.jl` that real users'
code resolves to via `using LithoWaferPlots`, and once as this extension's own
`@recipe`-generated implementation of the same name. Inside this module, a bare call
resolves to the extension's own local binding (it shadows the `using`-imported stub),
so a bare call in the workload only compiles+caches the local implementation — never
the stub's `Core.kwcall` wrapper, which is what a user's call site actually goes
through. That gap is invisible in isolated checks against the *extension's* internal
function but shows up immediately in `--trace-compile` against real user code. Verify
with `--trace-compile` against a script that does `using LithoWaferPlots, CairoMakie`
and calls things bare (matching real usage) — not against calls qualified with
`LithoWaferPlotsMakieExt.` or made from inside this file.

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
| `fields.jl` | Field-resolved analysis: `FieldedData` (`fielded`), `full_fields`/`partial_fields`/`filter_full`, `serpentine_numbers`, `stack_fields`→`AveragedField`, `field_average_profiles` (slit/scan), `field_kpis`, `average_wafers`, `ArrowScale` (`arrow_scale`/`arrow_scale_from`) |
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

### Per-backend precompile-only extensions

`ext/LithoWaferPlotsCairoMakieExt.jl`, `ext/LithoWaferPlotsGLMakieExt.jl`, and
`ext/LithoWaferPlotsWGLMakieExt.jl` are flat (no submodule) extensions, each triggered
by its concrete backend **and** `Makie` (e.g. `["CairoMakie", "Makie"]`) — the `Makie`
co-trigger is required, not decorative: an extension's own precompilation only loads its
declared triggers, so without it `LithoWaferPlotsMakieExt` (trigger: `Makie` alone) is
never loaded during, say, `LithoWaferPlotsCairoMakieExt`'s precompile, and the stub
functions it calls (`wafer_figure`, `waferheatmap!`, ...) throw "load a Makie backend
first". These extensions contain no recipe logic — they call the same public stub
functions everyone else does, then render once through their concrete backend
(`colorbuffer(fig)` for CairoMakie/GLMakie; a `Bonito` session/DOM serialization for
WGLMakie, no browser needed) purely to precompile that backend's draw dispatch for our
recipe types. `LithoWaferPlotsMakieExt`'s own workload never does this since it only
weak-deps on abstract `Makie` — building a `Scene`/recipe object doesn't touch any
backend's rendering code at all until a concrete backend actually draws it.
GLMakie's render is wrapped in `try/catch` (best-effort: no GL context in headless
CI/no-GPU installs must not fail the package install) — CairoMakie and WGLMakie's
render paths need no GPU/display and are unconditional, matching the exact idiom each
backend's own `src/precompiles.jl` uses.

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
The extension's precompile workload (bottom of `LithoWaferPlotsMakieExt.jl`, a
`PrecompileTools.@compile_workload` block) must exercise **every recipe** — add new
recipes to it. If a new recipe/attribute combination draws through `draw_fields!`
(needs a non-empty `fields` vector to get past its `isempty` fast path) or adds a new
constructor call shape (e.g. an omitted-default-argument overload), add that combination
too — `--trace-compile` on a realistic script is how these gaps get found; "the workload
calls it" isn't proof it compiled the same specialization a real script does. New recipes
also need a render call added to each of the three per-backend extensions (see above) so
their backend-specific draw dispatch precompiles too.

Precompilation is undone by *invalidations*: never overload `Base.show(::IO, ::Type{X})` or
other broad type/print methods — they invalidate the whole pipeline and recompile seconds of
code on first plot. After dependency bumps, audit with `SnoopCompile`'s
`@snoop_invalidations` (see `docs/src/performance.md`); keep total invalidations in the tens.
Note: `SnoopCompile` (not `SnoopCompileCore`) fails to precompile on Julia 1.12 if the
resolver is left to pick a version freely — it silently downgrades to an ancient
pre-2020 release. Pin explicitly: `Pkg.add(Pkg.PackageSpec(name="SnoopCompile", version="3.2.7"))`
(or newer). Its `report_invalidations` (PrettyTables-based) is separately broken on 1.12
(`Core.Binding` field-name change) — use `invalidation_trees`/`uinvalidated` directly.

## Requirements

- Never add Makie as a hard `[deps]` entry — keep it in `[weakdeps]`.
- All plot recipes must overlay the wafer boundary (circle + V-notch) automatically.
- Performance target: 300 000 points in < 0.3 s (GLMakie, median). Run benchmarks before PRs.
- Tests use `@testitem` (ReTestItems.jl). No bare `@testset`.
- Rendering tests must carry `tags=[:rendering]` and guard against headless environments.
- TypeContracts: add `@verify MyKPI` after any new `AbstractKPI` implementation.
- Run `runic -i .` from the repo root before every git commit.
- The extension must work with **all three backends**: CairoMakie, GLMakie, and WGLMakie.
  Never use backend-specific APIs in `LithoWaferPlotsMakieExt` itself — the one exception
  is the three dedicated precompile-only extensions (`ext/LithoWaferPlotsCairoMakieExt.jl`,
  `...GLMakieExt.jl`, `...WGLMakieExt.jl`), whose entire purpose is backend-specific
  rendering at precompile time (see above). They contain no recipe logic of their own.
- `docs/Project.toml` includes AlgebraOfGraphics and DataFrames for example generation.
  Do not add these to the main `[deps]`.
- **Gallery plots must show their generating code.** Every plot in `docs/src/gallery.md`
  is a live Documenter ` ```@example gallery ` block whose last expression is the `fig`, so
  the rendered image is produced by exactly the code shown above it. New gallery entries
  must follow this pattern — never a static `![](assets/…)` image with a hand-written
  snippet (they drift). Shared synthetic-data helpers live in the hidden ` ```@setup gallery `
  block. `docs/generate_examples.jl` is only for the few static images embedded by *other*
  pages (getting_started, index, aog_compositing).
