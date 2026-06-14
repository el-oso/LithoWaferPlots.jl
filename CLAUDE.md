# CLAUDE.md

## Commands

```julia
# Run all tests
julia --project=test -e 'using ReTestItems; runtests("LithoWaferPlots")'

# Run a single test item by name
julia --project=test -e 'using ReTestItems; runtests("LithoWaferPlots"; name=r"WaferSpec")'

# Skip rendering tests (headless CI)
julia --project=test -e 'using ReTestItems; runtests("LithoWaferPlots"; tags=[:rendering] |> exclude)'

# Run benchmarks
julia --project=. benchmarks/render_bench.jl

# Build docs
julia --project=docs docs/make.jl
```

## Architecture

`src/LithoWaferPlots.jl` is the module root (exports + includes only).

| File | Contents |
|---|---|
| `types.jl` | `WaferSpec`, `DieGrid`, `WaferField`, `WaferDie`, `WaferData`, `WaferVectorData` |
| `geometry.jl` | `wafer_polygon`, `inside_wafer`, `field_bounds`, `die_bounds` |
| `input.jl` | Tables.jl constructors for mm-coord and die-index modes |
| `contracts.jl` | `AbstractKPI` contract via TypeContracts.jl |
| `kpi.jl` | Built-in KPI structs; `DEFAULT_KPIS`; `format_value` fallback |
| `colorscale.jl` | `ColorScale`, `normalize` |
| `vectorfields.jl` | `divergence`, `vorticity` (interpolate → grid → finite diff) |

Makie rendering lives entirely in `ext/LithoWaferPlotsMakieExt/` — loaded only
when Makie is in the environment. No Makie symbols in `src/`.

## Requirements

- Never add Makie as a hard `[deps]` entry — keep it in `[weakdeps]`.
- All plot recipes must overlay the wafer boundary (circle + V-notch) automatically.
- Performance target: 300 000 points in < 0.3 s (GLMakie, median). Run benchmarks before PRs.
- Tests use `@testitem` (ReTestItems.jl). No bare `@testset`.
- Rendering tests must carry `tags=[:rendering]` and guard against headless environments.
- TypeContracts: add `@verify MyKPI` after any new `AbstractKPI` implementation.
