"""
# HOW THIS WORKS:
the PackageSpec written in this file will be used to import Pluto during these tests.

# DO I NEED IT?
When developing PlutoDependencyExplorer, and you don't need matching changes from Pluto, then leave this file empty.

In the special case that you need to make changes to PlutoDependencyExplorer and Pluto at the same time, you can use this file.


# HOW TO USE IT
## Step 1:
If this change needs a matching Pluto change, set:
```julia
i_need_a_special_pluto_branch = true
```
and continue to Step 2. Otherwise, set it to `false` and you're done.


## Step 2:


"""



i_need_a_special_pluto_branch = true


if i_need_a_special_pluto_branch
    if get(ENV, "CI", "🍄") == "true"
        Pkg.PackageSpec(
            name="Pluto",
            rev="PlutoDependencyExplorer-split",
        )
    else
        Pkg.PackageSpec(
            name="Pluto",
            path="/Users/fons/Documents/Pluto.jl"
        )
    end
else
    nothing
end


