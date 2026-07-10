# Performance

## Time to first plot

The Makie extension runs a `PrecompileTools.@compile_workload` (only executes during
`Pkg.precompile()`) that exercises **every recipe** plus the layout, annotation and
overlay helpers. Subsequent Julia sessions reuse the cached native code, so the first
plot of a session is fast (e.g. first `waferarrows!` ≈ 0.3 s instead of ~3.5 s).

That workload only precompiles recipe *construction* — it never renders a frame, since
it only weak-deps on abstract `Makie`, never a concrete backend. Backend-specific draw
dispatch (CairoMakie's Cairo calls, GLMakie's shader/screen setup, WGLMakie's JS
serialization) only compiles once a concrete backend actually draws something, so three
small, backend-specific extensions (`ext/LithoWaferPlotsCairoMakieExt.jl`,
`...GLMakieExt.jl`, `...WGLMakieExt.jl`) each render a representative figure through
their own backend at precompile time to warm that path too.

Run precompilation explicitly after installation or after upgrading packages:

```
julia -e 'using Pkg; Pkg.precompile()'
```

!!! note "Invalidations matter as much as precompilation"
    A precompile workload only helps if its cached code is not *invalidated* when a backend
    loads. A single overly-broad method in a dependency (e.g. `Base.show(::IO, ::Type{X})`)
    can invalidate the whole type/print pipeline and force seconds of recompilation on the
    first plot — even for already-precompiled paths. If first-plot time regresses, check for
    invalidations with `SnoopCompile`:
    ```julia
    using CairoMakie, SnoopCompileCore
    invs = @snoop_invalidations using LithoWaferPlots
    using SnoopCompile
    length(uinvalidated(invs))   # should be small (tens, not thousands)
    ```
    On Julia 1.12, letting the resolver pick `SnoopCompile` freely can silently install an
    ancient pre-2020 release (its ecosystem-wide ⌅/compat chain resolves backwards). Pin it
    explicitly: `Pkg.add(Pkg.PackageSpec(name="SnoopCompile", version="3.2.7"))` (or newer).
    Its `report_invalidations` (needs `PrettyTables`) is separately broken on 1.12 due to a
    `Core.Binding` field rename — use `invalidation_trees(invs)`/`uinvalidated(invs)` directly
    instead of the pretty-printed report.

### Pinning Makie for reproducible startup times

Makie releases occasionally change which methods are precompiled, which can make startup
times regress unexpectedly when you update. Pin the Makie version in your project to keep
startup time stable:

```
julia --project=. -e 'using Pkg; Pkg.pin("Makie"); Pkg.pin("CairoMakie")'
```

Unpin when you deliberately want to upgrade:

```
julia --project=. -e 'using Pkg; Pkg.free("Makie"); Pkg.free("CairoMakie")'
```

### PackageCompiler sysimage (< 0.5 s total)

For the lowest possible latency — including the `using` time — build a custom sysimage
with [PackageCompiler.jl](https://julialang.github.io/PackageCompiler.jl/stable/):

```julia
using PackageCompiler
create_sysimage(
    [:LithoWaferPlots, :CairoMakie];
    sysimage_path = "lwp.so",
    precompile_execution_file = "my_precompile_script.jl",
)
```

Launch Julia with `julia --sysimage lwp.so` to use it. The build takes ~10 minutes but
the resulting image starts in under 0.5 s.

---

## Benchmarking with PkgBenchmark

The `benchmarks/` directory contains a [PkgBenchmark.jl](https://github.com/JuliaCI/PkgBenchmark.jl)
suite with two groups:

| Group | What it measures | Backend |
|---|---|---|
| `compute` | masking, colour scaling, divergence/vorticity, KPIs | any (CairoMakie) |
| `render` | full plot construction for every recipe | CairoMakie (CPU) |

## Latest benchmark results

The report below is **regenerated on every documentation build** by `docs/make.jl`,
which runs the suite through PkgBenchmark. Absolute timings reflect the machine that built
these docs — a shared CI runner unless built locally — so treat them as indicative rather
than authoritative. For tracking regressions across commits, use `judge` (below).

```@eval
using Markdown, LithoWaferPlots
Markdown.parse(
    read(
        joinpath(pkgdir(LithoWaferPlots), "docs", "generated", "benchmark_report.md"),
        String,
    )
)
```

## Running the suite yourself

```julia
using PkgBenchmark, LithoWaferPlots

results = benchmarkpkg(
    LithoWaferPlots;
    script = joinpath(pkgdir(LithoWaferPlots), "benchmarks", "benchmarks.jl"),
)
export_markdown(stdout, results)
```

Because the suite lives in `benchmarks/` (not the PkgBenchmark default `benchmark/`),
always pass the `script` keyword as shown above.

### Comparing commits for regressions

```julia
script   = joinpath(pkgdir(LithoWaferPlots), "benchmarks", "benchmarks.jl")
baseline = benchmarkpkg(LithoWaferPlots, "main"; script)
current  = benchmarkpkg(LithoWaferPlots; script)
export_markdown(stdout, judge(current, baseline))
```

A `judge` result marks each benchmark as `+` (regression), `-` (improvement),
or `≡` (invariant, within noise tolerance). Comparing against a named commit requires a
clean working tree.

### GPU rendering (GLMakie)

The suite uses CairoMakie for portability. For GPU-accelerated numbers on
a machine with a display, run the standalone script:

```
julia --project=benchmarks benchmarks/render_bench.jl
```

---

## Target

All plot types must render **300 000 points in < 0.3 s** (median wall time, GLMakie GPU path).

## Running benchmarks (legacy scripts)

`compute_bench.jl` is headless-safe (no display needed); `render_bench.jl` requires GLMakie
and a display — see [GPU rendering (GLMakie)](@ref) above.

```julia
julia --project=benchmarks benchmarks/compute_bench.jl
julia --project=benchmarks benchmarks/render_bench.jl
```

## Key design decisions

| Decision | Benefit |
|---|---|
| `GLMakie` GPU backend | Single GPU draw call for scatter/heatmap |
| Pre-allocated `Float32` colour arrays | No per-point allocation in Julia |
| `scatter!` with `:rect` marker for heatmap | Faster than `heatmap!` on scattered points |
| `image!` for gridded heatmap | Single texture upload |
| Arrows as one batched `lines!` (shaft + V head), subsampled to `max_arrows` (default 4 000) | One draw call instead of a tessellated mesh per arrow — ~10× less memory |
| Streamlines as single `lines!` with `NaN` separators | One draw call for all lines |
| Streamlines trace on a precomputed velocity grid (`grid_n`, bilinear sampling) | One interpolation pass instead of a `knn` search at every RK4 sub-step — ~5× faster |
| IDW interpolation with `knn!` + reused buffers, `k = 4` neighbours | No per-point allocations in contour / divergence / vorticity / streamlines; fewer neighbours per query |

## Tips for large datasets

- Use `GLMakie` (not `CairoMakie`, which is CPU-only).
- For heatmaps, pre-interpolate to a regular grid and use `image!` directly.
- For arrow plots, increase `max_arrows` only if GPU memory allows.
- Reduce `grid_n` (and the IDW `k`) in `WaferContour` / `WaferDivergence` / `WaferVorticity`
  for speed; raise them for smoother fields. `WaferStreamlines` also takes `grid_n` for its
  sampling grid.
- Pass `Float32` values (not `Float64`) to halve GPU memory bandwidth.
