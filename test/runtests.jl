# Entry point when using the test/ project environment.
# For CI: julia --project=test test/runtests.jl
# During development it's faster to run from the main project:
#   julia --project=. -e 'using LithoWaferPlots, ReTestItems, TypeContracts, Statistics; include.(readdir("test", join=true) |> filter(f->endswith(f,".jl") && f!="runtests.jl"))'

using LithoWaferPlots
using ReTestItems

const SKIP_RENDERING = !haskey(ENV, "DISPLAY") && !haskey(ENV, "WAYLAND_DISPLAY")

runtests(
    ti -> !(SKIP_RENDERING && :rendering in ti.tags),
    LithoWaferPlots;
    testitem_timeout = 120,
    nworkers = 0,
)
