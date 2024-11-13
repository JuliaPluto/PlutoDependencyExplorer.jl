"""
# HOW THIS WORKS:
the PackageSpec written in this file will be used to import Pluto during these tests.

# DO I NEED IT?
When developing PlutoDependencyExplorer, and you don't need matching changes from Pluto, then leave this file as-is.

In the special case that you need to make changes to PlutoDependencyExplorer and Pluto at the same time, you can edit this file to test those changes.


# HOW TO USE IT
Uncomment the PackageSpec that best matches your needs.

"""


function get_spec()


    # DEFAULT: use the latest development Pluto
    Pkg.PackageSpec(
        name="Pluto",
        rev="main",
    )

    # EXAMPLE: use a specific branch of Pluto
    # Pkg.PackageSpec(
    #     name="Pluto",
    #     rev="something-different",
    # )

    # LOCAL DEVELOPMENT: use a local copy of Pluto
    # Pkg.PackageSpec(
    #     name="Pluto",
    #     path="/Users/fons/Documents/Pluto.jl"
    # )

end



get_spec()
