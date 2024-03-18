using Test
import PlutoDependencyExplorer as PDE

@testset "Basic API" begin
    struct SimpleCell <: PDE.AbstractCell
            code
        end

    notebook = SimpleCell.([
            "x + y"
            "x = 1"
            "y = x + 2"
        ]);

    empty_topology = PDE.NotebookTopology{SimpleCell}();

    topology = PDE.updated_topology(
            empty_topology,
            notebook, notebook;
            get_code_str = c -> c.code,
            get_code_expr = c -> Meta.parse(c.code),
        );

    order = PDE.topological_order(topology);

    @test order.runnable == notebook[[2, 3, 1]]

    notebook = SimpleCell.([
        "foo"
        "foo = 3"
    ]);

    empty_topology = PDE.NotebookTopology{SimpleCell}();

    topology = PDE.updated_topology(
            empty_topology,
            notebook, notebook;
            get_code_str = c -> c.code,
            get_code_expr = c -> Meta.parse(c.code),
        );

    order = PDE.topological_order(topology);

    @test order.runnable == notebook[[2, 1]]
end