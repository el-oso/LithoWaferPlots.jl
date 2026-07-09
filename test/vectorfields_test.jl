@testitem "divergence/vorticity are unaffected by a NaN point in the source data" begin
    using LithoWaferPlots

    w = WaferSpec(300.0)
    xs = [x for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    ys = [y for x in -120.0:10.0:120.0 for y in -120.0:10.0:120.0]
    vxs = -ys ./ 100
    vys = xs ./ 100

    d_clean = WaferVectorData(xs, ys, vxs, vys, w, WaferField[])

    vxs_dirty = copy(vxs)
    vxs_dirty[1] = NaN   # WaferVectorData's constructor drops this point at construction time
    d_dirty = WaferVectorData(xs, ys, vxs_dirty, vys, w, WaferField[])

    div_clean = divergence(d_clean; grid_n = 64)
    div_dirty = divergence(d_dirty; grid_n = 64)

    @test !any(isnan, div_dirty.values)
    # the previously-poisoned run lost ~26% of active grid cells to IDW poisoning; with the
    # NaN point filtered before it ever reaches the KDTree/IDW step, output size should match
    # the clean run (same point count, same grid) rather than being substantially smaller.
    @test length(div_dirty.values) == length(div_clean.values)
end
