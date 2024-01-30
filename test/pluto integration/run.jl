import Pkg

pkg_source = include("./DEV EDIT ME pluto pkg source.jl")

if pkg_source !== nothing
    
    is_dev = if hasfield(typeof(pkg_source), :rev)
        pkg_source.rev === nothing
    else
        pkg_source.repo.rev === nothing
    end
    
    if is_dev
        Pkg.develop(pkg_source)
    else
        Pkg.add(pkg_source)
    end
end

import Pluto

include("./helpers.jl")

include("./identity.jl")
include("./React.jl")


