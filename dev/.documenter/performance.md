
# Performance {#Performance}

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
  
