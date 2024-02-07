


function insert_cell!(notebook, cell)
    notebook.cells_dict[cell.cell_id] = cell
    push!(notebook.cell_order, cell.cell_id)
end

function delete_cell!(notebook, cell)
    deleteat!(notebook.cell_order, findfirst(==(cell.cell_id), notebook.cell_order))
    delete!(notebook.cells_dict, cell.cell_id)
end

function setcode!(cell, newcode)
    cell.code = newcode
end

function noerror(cell; verbose=true)
    if cell.errored && verbose
        @show cell.output.body
    end
    !cell.errored
end

function occursinerror(needle, haystack::Pluto.Cell)
    haystack.errored && occursin(needle, haystack.output.body[:msg])
end

function expecterror(err, cell; strict=true)
    cell.errored || return false
    msg = sprint(showerror, err)

    # UndefVarError(:x, #undef)
    if err isa UndefVarError && !isdefined(err, :scope) && VERSION > v"1.10"
        strict = false
        msg = first(split(msg, '\n'; limit=2))
    end

    if strict
        return cell.output.body[:msg] == msg
    else
        return occursin(msg, cell.output.body[:msg])
    end
end