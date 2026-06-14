using Documenter
using DocumenterVitepress
using LithoWaferPlots

makedocs(;
    modules = [LithoWaferPlots],
    sitename = "LithoWaferPlots.jl",
    authors = "el_oso",
    format = DocumenterVitepress.MarkdownVitepress(
        devbranch = "master",
        devurl = "dev",
        repo = "github.com/el-oso/LithoWaferPlots.jl",
        sidebar_drawer = true
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Gallery" => "gallery.md",
        "Custom KPIs" => "custom_kpi.md",
        "AlgebraOfGraphics" => "aog_compositing.md",
        "Performance" => "performance.md",
        "API Reference" => "api.md",
    ],
    checkdocs = :exports,
    warnonly = [:missing_docs],
    remotes = nothing,
    doctest = false,
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/el-oso/LithoWaferPlots.jl",
    devbranch = "master",
    push_preview = true,
)
