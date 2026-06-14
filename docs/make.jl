using Documenter
using DocumenterVitepress
using LithoWaferPlots

makedocs(;
    modules = [LithoWaferPlots],
    sitename = "LithoWaferPlots.jl",
    authors = "el_oso",
    format = DocumenterVitepress.MarkdownVitepress(
        devbranch = "master",
        repo = "github.com/el-oso/LithoWaferPlots.jl",
    ),
    pages = [
        "Home"            => "index.md",
        "Getting Started" => "getting_started.md",
        "Gallery"         => "gallery.md",
        "Custom KPIs"     => "custom_kpi.md",
        "Performance"     => "performance.md",
        "API Reference"   => "api.md",
    ],
    checkdocs = :exports,
    warnonly  = [:missing_docs],
    remotes   = nothing,
    doctest   = false,
)
