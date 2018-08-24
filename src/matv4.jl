# This file is a part of PicoScopes.jl, licensed under the MIT License (MIT).


_decdigit(x::Integer, digit::Integer) = rem(div(x, 10^(digit - 1)), 10)


struct MATv4Header
    dtype::UInt32
    mrows::UInt32
    ncols::UInt32
    imagf::UInt32
    namlen::UInt32
end


function Base.read(src::IO, ::Type{MATv4Header})
    dtype = ltoh(read(src, UInt32))
    mrows = ltoh(read(src, UInt32))
    ncols = ltoh(read(src, UInt32))
    imagf = ltoh(read(src, UInt32))
    namlen = ltoh(read(src, UInt32))

    MATv4Header(dtype, mrows, ncols, imagf, namlen)
end


@enum MatrixType numeric_matrix=0 text_matrix=1 sparse_matrix=2


function matrix_type(header::MATv4Header)
    return MatrixType(_decdigit(header.dtype, 1))
end


function matrix_numtype(header::MATv4Header)
    numtype = _decdigit(header.dtype, 2)
    tp = if numtype == 0
        Float64
    elseif numtype == 1
        Float32
    elseif numtype == 2
        Int32
    elseif numtype == 3
        Int16
    elseif numtype == 4
        UInt16
    elseif numtype == 5
        UInt8
    else
        error("Invalid MATv4 number type: $numtype")
    end

    is_complex = if header.imagf == 0
        false
    elseif header.imagf == 1
        true
    else
        error("Invalid value for MATv4 imagf: $(header.imagf)")
    end

    is_complex ? Complex{tp} : tp
end


function byte_order(header::MATv4Header)
    endianess = _decdigit(header.dtype, 4)
    if endianess == 0
        false  # little endian
    elseif endianess == 1
        true # big endian
    else
        # VAX D-float, VAX G-float or Cray
        error("Unsupported MATv4 endianess format: $endianess")
    end
end



struct MATv4Data{T<:Number}
    name::String
    data::Matrix{T}
end


function _read_matv4_name(src::IO, header::MATv4Header)
    bytes = read!(src, Vector{UInt8}(undef, header.namlen))
    transcode(String, bytes[1:end-1])
end


function _read_matv4_data(src::IO, T::Type{<:Real}, mrows::Integer, ncols::Integer, big_endian::Bool)
    data = Matrix{T}(undef, mrows, ncols)
    read!(src, data)

    if big_endian && ntoh(1) != 1
        data .= ntoh.(data)
    elseif ltoh(1) != 1
        data .= ltoh.(data)
    end

    data
end


function Base.read(src::IO, ::Type{MATv4Data})
    header = read(src, MATv4Header)
    name = _read_matv4_name(src, header)
    T = matrix_numtype(header)
    data = _read_matv4_data(src, T, header.mrows, header.ncols, byte_order(header))
    MATv4Data(name, data)
end
