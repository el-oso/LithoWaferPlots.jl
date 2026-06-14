
# Performance {#Performance}

## Time to first plot {#Time-to-first-plot}

LithoWaferPlots ships a `PrecompileTools` workload that is executed once during `Pkg.precompile()`. Subsequent Julia sessions skip recompiling the recipe methods, cutting time-to-first-plot from **~5–12 s to ~0.1–0.5 s** (after `using` returns).

Run precompilation explicitly after installation or after upgrading packages:

```
julia -e 'using Pkg; Pkg.precompile()'
```


### Pinning Makie for reproducible startup times {#Pinning-Makie-for-reproducible-startup-times}

Makie releases occasionally change which methods are precompiled, which can make startup times regress unexpectedly when you update. Pin the Makie version in your project to keep startup time stable:

```
julia --project=. -e 'using Pkg; Pkg.pin("Makie"); Pkg.pin("CairoMakie")'
```


Unpin when you deliberately want to upgrade:

```
julia --project=. -e 'using Pkg; Pkg.free("Makie"); Pkg.free("CairoMakie")'
```


### PackageCompiler sysimage (&lt; 0.5 s total) {#PackageCompiler-sysimage--0.5-s-total}

For the lowest possible latency — including the `using` time — build a custom sysimage with [PackageCompiler.jl](https://julialang.github.io/PackageCompiler.jl/stable/):

```julia
using PackageCompiler
create_sysimage(
    [:LithoWaferPlots, :CairoMakie];
    sysimage_path = "lwp.so",
    precompile_execution_file = "my_precompile_script.jl",
)
```


Launch Julia with `julia --sysimage lwp.so` to use it. The build takes ~10 minutes but the resulting image starts in under 0.5 s.


---


## Target {#Target}

All plot types must render **300 000 points in &lt; 0.3 s** (median wall time, GLMakie GPU path).

## Running benchmarks {#Running-benchmarks}

```julia
julia --project=.. benchmarks/render_bench.jl
```


## Key design decisions {#Key-design-decisions}

|                                             Decision |                                    Benefit |
| ----------------------------------------------------:| ------------------------------------------:|
|                                `GLMakie` GPU backend |   Single GPU draw call for scatter/heatmap |
|                Pre-allocated `Float32` colour arrays |           No per-point allocation in Julia |
|           `scatter!` with `:rect` marker for heatmap | Faster than `heatmap!` on scattered points |
|                         `image!` for gridded heatmap |                      Single texture upload |
|                           Arrow subsampling to ≤ 20K |             Arrow plot readability + speed |
| Streamlines as single `lines!` with `NaN` separators |                One draw call for all lines |


## Tips for large datasets {#Tips-for-large-datasets}
- Use `GLMakie` (not `CairoMakie`, which is CPU-only).
  
- For heatmaps, pre-interpolate to a regular grid and use `image!` directly.
  
- For arrow plots, increase `max_arrows` only if GPU memory allows.
  
- Reduce `grid_n` in `WaferContour` / `WaferDivergence` / `WaferVorticity` for speed.
  
- Pass `Float32` values (not `Float64`) to halve GPU memory bandwidth.
  
