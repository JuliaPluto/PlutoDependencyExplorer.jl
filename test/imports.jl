using Test
import PlutoDependencyExplorer as PDE
import PlutoDependencyExplorer.ExpressionExplorer

@testset "external_package_names" begin
    struct SimpleCell <: PDE.AbstractCell
        code
    end

    notebook = SimpleCell.([
        "using Plots, Example.Something"
        """begin
            import .Yoooo
            import Sick: nice
        end"""
        ":(import Nonono)"
    ]);

    empty_topology = PDE.NotebookTopology{SimpleCell}();

    topology = PDE.updated_topology(
        empty_topology,
        notebook, notebook;
        get_code_str = c -> c.code,
        get_code_expr = c -> Meta.parse(c.code),
    );
    
    @test ExpressionExplorer.external_package_names(topology) == Set([:Plots, :Example, :Sick])
        
end