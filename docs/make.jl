include("../src/MPOPF.jl")
using .MPOPF

using Documenter

makedocs(
    sitename = "MPOPF.jl",
    format = Documenter.HTML(),
    modules = [MPOPF],
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/getting_started.md",
            "Types" => "manual/types.md",
            "Functions" => "manual/functions.md",
        ],
        "API" => "api.md"
    ]
)
