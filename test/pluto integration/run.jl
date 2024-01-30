import Pkg

pkg_source = include("./DEV EDIT ME pluto pkg source.jl")

if pkg_source !== nothing
    if pkg_source.rev === nothing
        Pkg.develop(pkg_source)
    else
        Pkg.add(pkg_source)
    end
end

import Pluto

include("./helpers.jl")

include("./identity.jl")
include("./React.jl")


