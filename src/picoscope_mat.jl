# This file is a part of PicoScopes.jl, licensed under the MIT License (MIT).


function read_picoscope_mat(filename::AbstractString)
    open(filename) do src
        result = Dict{Symbol,Matrix}()
        #while !eof(src)
        for i in 1:8
            data = read(src, PicoScopes.MATv4Data)
            result[Symbol(data.name)] = data.data
        end
        result
    end
end

export read_picoscope_mat
