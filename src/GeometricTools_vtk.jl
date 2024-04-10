#=##############################################################################
# DESCRIPTION
    Methods for VTK Legacy formatting
# AUTHORSHIP
  * Author    : Eduardo J Alvarez
  * Email     : Edo.AlvarezR@gmail.com
  * Created   : Nov 2017
  * License   : MIT License
=###############################################################################


"""
  `lines2vtk(lines; values=nothing)`

  Receives an array of lines, with lines[i] the i-th line, and lines[i][j] the
  j-th point in the i-th line, and formats them in vtk format. Give it point
  data through `values` in the same format, and it will output the data formated
  as corresponding to the vtk lines.

  ** Output **
  * (points, vtk_lines, vtk_values) where `points` is an array with all points
    in all lines, `lines` is an array of arrays containing the indices of
    every point in each line, and `vtk_values` is an array with the point data
    of each point in `points`.
"""
function lines2vtk(lines; values=nothing)
  points = Array{Float64,1}[]
  vtk_lines = Array{Int64,1}[]

  if values!=nothing
    vtk_values = []
  else
    vtk_values = nothing
  end

  n_points = 0
  for (i,line) in enumerate(lines)
    vtk_line = []
    for (j,point) in enumerate(line)
      push!(points, point)
      push!(vtk_line, n_points)
      if values!=nothing
        push!(vtk_values, values[i][j])
      end
      n_points += 1
    end
    push!(vtk_lines, vtk_line)
  end

  return (points, vtk_lines, vtk_values)
end


"""
  `generateCells(line1::Array{Array{Float64,1}},line2::Array{Array{Float64,1}};
                    point_data1, point_data2)`

Given two lines with the same amount of points, it generate cells by matching
the points between lines. For instance:

  ```julia
  julia> line1 = [p11,p12,p13,p14,p15,p16,p17]
  julia> line2 = [p21,p22,p23,p24,p25,p26,p27]
  julia> generateCells(line1, line2)
  ([cell1, cell2, ...], point_data)
  ```
where `cell1=[p11, p12, p22, p21]`, `cell2=[p12,p13,p23,p22]`, etc.

Give it point data corresponding to points in each line through `point_data1`
and `point_data2`, and it return it through `point_data` formatted for
`lines2vtk`'s `values` input.
"""
function generateCells(line1, line2; point_data1=nothing, point_data2=nothing)
  # Error case
  if size(line1)!=size(line2)
    error("Cells can't be generated from lines of unequal divisions!")
  end

  ncells = size(line1)[1]-1   # Number of cells
  cells = Array{Float64,1}[]  # Cells
                              # Point data on each cell
  point_data = (nothing in [point_data1, point_data2]) ? nothing : []

  # Builds cells
  for i in 1:ncells
    push!(cells, [line1[i], line1[i+1], line2[i+1], line2[i]])
    if point_data!=nothing
      push!(point_data, [point_data1[i], point_data1[i+1], point_data2[i+1],
                        point_data2[i]])
    end
  end

  return cells, point_data
end


"""
  `lines2vtkcells(line1::Array{Array{Float64,1}},line2::Array{Array{Float64,1}};
                    point_data1, point_data2)`

Given two lines with the same amount of points, it generate cells in VTK format
by matching the points between lines. For instance:

  ```julia
  julia> line1 = [p11,p12,p13]
  julia> line2 = [p21,p22,p23]
  julia> lines2vtkcells(line1, line2)
  (points, vtk_cells, point_data)
  ```
where `points=[p11,p12,p13,p21,p22,p23]`, and `vtk_cells=[[0,1,4,3],[1,2,5,4]]`.

Give it point data corresponding to points in each line through `point_data1`
and `point_data2`, and it return it through `point_data` formatted for
`generateVTK`'s `point_data` input.

Prefer this method over `generateCells()` since it will store the data
efficiently when generating the VTK.
"""
function lines2vtkcells(line1, line2; point_data1=nothing, point_data2=nothing)
  # Error case
  if size(line1)!=size(line2)
    error("Cells can't be generated from lines of unequal divisions!")
  end

  npoints = size(line1)[1]        # Number of points per line
  ncells = npoints-1              # Number of cells
  points = vcat(line1, line2)     # Points
  vtk_cells = Array{Int64,1}[]    # Cells
  # Point data
  if !(nothing in [point_data1, point_data2])
    if size(point_data1)!=size(point_data2)
      error("Invalid point data! "*
            "$(size(point_data1))!=$(size(point_data2))"*
            "(size(point_data1)!=size(point_data2))")
    else
      point_data = vcat(point_data1, point_data2)
    end
  else
    point_data = nothing
  end

  # Builds cells
  for i in 1:ncells
    point_index = i-1
    push!(vtk_cells, [point_index, point_index+1,
                        npoints+point_index+1, npoints+point_index])
  end

  return points, vtk_cells, point_data
end

"""
  `lines2vtkmulticells(line1, line2,
                          sections::Array{Tuple{Float64,Int64,Float64,Bool},1},
                          point_data1=nothing, point_data2=nothing)`

Like `lines2vtkcells()` it generates cells between two lines, but allows to
define multiple rows of cells in between. The rows are given by `sections`,
which is the same variable `sections` defined in `VTKtools_geometry.jl`'s
`multidiscretize()` function, which divides the space in between the lines.
For more details see docstring of `lines2vtkcells()` and `multidiscretize()`.
"""
function lines2vtkmulticells(line1, line2,
                          sections::Array{Tuple{Float64,Int64,Float64,Bool},1};
                          point_data1=nothing, point_data2=nothing)
  # ERROR CASES
  if size(line1)!=size(line2)
    error("Cells can't be generated from lines of unequal divisions!")
  end
  if !(nothing in [point_data1, point_data2])
    if size(point_data1)!=size(point_data2)
      error("Invalid point data! "*
            "$(size(point_data1))!=$(size(point_data2))"*
            "(size(point_data1)!=size(point_data2))")
    else
      point_data = []
    end
  else
    point_data = nothing
  end


  npoints = size(line1)[1]        # Number of points per line
  points = []                     # Points
  vtk_cells = Array{Int64,1}[]    # Cells

  # Discretize the space between the lines
  f(x) = x              # Function to discretize
  xlow, xhigh = 0, 1    # The space is parameterized between 0 and 1
  row_pos = multidiscretize(f, xlow, xhigh, sections) # Position of each row
                                                      # between the lines

  # Iterates over each row
  prev_line2 = line1
  prev_point_data2 = point_data1
  for (i,this_pos) in enumerate(row_pos[2:end])

    # Creates the upper and lower lines of this row
    this_line1 = prev_line2
    this_line2 = [line1[j] + this_pos*(line2[j]-line1[j]) for j in 1:npoints]

    # Linearly interpolates point data
      this_point_data1 = prev_point_data2
    if point_data!=nothing
      this_point_data2 = [point_data1[j] + this_pos*(point_data2[j]-point_data1[j]) for j in 1:npoints]
    else
      this_point_data2 = nothing
    end


    # Discretizes this row
    row = lines2vtkcells(this_line1, this_line2; point_data1=this_point_data1,
                                                  point_data2=this_point_data2)
    row_points, row_vtk_cells, row_point_data = row

    # Adds this row to the overall mesh
    if i==1 # Case of the first row of cells (adds both upper and lower bound)
      # Adds points
      points = vcat(points, row_points)
      # Adds point data
      if point_data!=nothing
        point_data = vcat(point_data, row_point_data)
      end
    else # Case of other rows (only adds upper bound)
      # Adds points
      points = vcat(points, row_points[npoints+1:end])
      # Adds point data
      if point_data!=nothing
        point_data = vcat(point_data, row_point_data[npoints+1:end])
      end
    end
    # Adds point indexing of cells
    vtk_cells = vcat(vtk_cells,
                            [cells .+ (i-1)*npoints for cells in row_vtk_cells])

    prev_line2 = this_line2
    prev_point_data2 = this_point_data2
  end

  return points, vtk_cells, point_data
end

"""
  `multilines2vtkmulticells(lines::Array{Array{Array{Float64,1 },1},1},
                  sections::Array{Array{Tuple{Float64,Int64,Float64,Bool},1},1};
                  point_datas=nothing)`

Expanding `lines2vtkmulticells()` it generates cells in multiple rows of cells
in between multiple lines. The rows in between each line are given by `sections`
which is an array of `sections` defined in `lines2vtkmulticells()` which divides
the space in between the lines.

For more details see docstring of `lines2vtkmulticells()`.
"""
function multilines2vtkmulticells(lines,
                  sections::Array{Array{Tuple{Float64,Int64,Float64,Bool},1},1};
                  point_datas=nothing)
  nlines = size(lines)[1]         # Number of lines
  npoints = size(lines[1])[1]     # Number of points on each line
  pflag = point_datas!=nothing     # Flag for point data


  # ERROR CASES
  if nlines<=1
    error("Two or more lines are required. Received $nlines.")
  elseif pflag && size(point_datas)[1]!=nlines
    error("Invalid point data. "*
            "$(size(point_datas)[1])!=$(nlines) (size(point_datas)[1]!=nlines)")
  elseif size(sections)[1]!=(nlines-1)
    error("Invalid number of sections."*
            " Expected $(nlines-1), received $(size(sections)[1])")
  else
    for line in lines
      if size(line)[1]!=npoints
        error("All lines must have the same number of points."*
            " Expected $npoints, found $(size(line)[1]).")
      end
    end
  end

  # Outputs
  points = []
  vtk_cells = Array{Int64,1}[]
  point_data = pflag ? [] : nothing

  for (i,line) in enumerate(lines)
    if i==1
      nothing
    else

      cur_npoints = size(points, 1)   # Current number of points

      # Meshes this section
      out = lines2vtkmulticells(lines[i-1], line,
                              sections[i-1];
                              point_data1=pflag ? point_datas[i-1] : nothing,
                              point_data2=pflag ? point_datas[i] : nothing)

      this_points, this_vtk_cells, this_point_data = out

      # Adds this section to the overall mesh
      if i==2 # Case of the first section (adds both upper and lower bound)
        # Adds points
        points = vcat(points, this_points)
        # Adds point data
        if pflag
          point_data = vcat(point_data, this_point_data)
        end
      else # Case of any other section (only adds upper bound)
        # Adds points
        points = vcat(points, this_points[npoints+1:end])
        # Adds point data
        if point_data!=nothing
          point_data = vcat(point_data, this_point_data[npoints+1:end])
        end
      end
      # Adds point indexing of cells
      this_zero = cur_npoints - npoints*(i!=2) # Point index corresponding to
                                               # this cell's zero
      vtk_cells = vcat(vtk_cells, [cells.+this_zero for cells in this_vtk_cells])
    end
  end

  return points, vtk_cells, point_data
end

"""
    `read_vtk(filename; path="")`

Read the VTK legacy file `filename` in the directory `path`, and returns
`(points, cells, cell_types, data)`.
"""
function read_vtk(filename::String; path::String="", fielddata=Dict())

    f = open(joinpath(path, filename), "r")

    # -------------- HEADER ------------------------------------------
    version = readline(f)             # VTK version
    header = readline(f)              # Header
    format = readline(f)              # VTK format

    if format != "ASCII"
        error("Only ASCII files currently supported; found $format.")
    end

    dataset_type = readline(f)[9:end] # Dataset type

    if dataset_type != "UNSTRUCTURED_GRID"
        error("Only UNSTRUCTURED_GRID dataset type current supported;"*
                    " found $dataset_type.")
    end

    # -------------- POINTS -------------------------------------------
    ln = readline(f)

    # Read fields
    while ln[1:5]=="FIELD"      # Iterate over fields
        dataname = split(ln, " ")[2]    # Data name
        narr = Base.parse(Int, split(ln, " ")[3])  # Number of arrays

        fielddata[dataname] = Dict{String, Array{Float64}}()

        for ai in 1:narr    # Read arrays
            ln = readline(f)
            splt = split(ln, " ")

            arrayname = splt[1]         # Array name
            nc = Base.parse(Int, splt[2])    # Number of components
            nt = Base.parse(Int, splt[3])    # Number of tuples
            datatype = splt[4]          # Data type

            if datatype!="double"
                @warn("Reading data type $datatype as Float64!")
            end

            fielddata[dataname][arrayname] = Array{Float64}(undef, nt, nc) #pre-allocate

            for ti in 1:nt      # Read tuples
                comps = Base.parse.(Float64, split(readline(f), " ")) # Read components
                if length(comps)!=nc
                    error("LOGIC ERROR! Expected $nc components, got $(length(comps)).")
                end
                fielddata[dataname][arrayname][ti, :] = comps
            end
        end

        ln = readline(f)
    end

    if ln[1:6]!="POINTS"
        error("Expected to find POINTS, found $(ln[1:7]).")
    end

    np = Base.parse(Int, split(ln, " ")[2])  # Number of points
    preal = split(ln, " ")[3]           # Point data real type

    # Read points
    points = Array{Float64}(undef, 3, np) #pre-allocate
    for pi in 1:np
        points[:, pi] .= Base.parse.(Float64, split(readline(f), " "))
    end


    # -------------- CELLS --------------------------------------------

    # Skip empty lines
    ln = skip_empty_lines(f)

    if ln[1:5]!="CELLS"
        error("Expected to find CELLS, found $(ln[1:7]).")
    end

    nc = Base.parse(Int, split(ln, " ")[2])      # Number of cells
    csize = Base.parse(Int, split(ln, " ")[3])   # Cell list size

    # Read cells
    cells = Array{Int, 1}[]
    for ci in 1:nc
        aux = readline(f)
        while occursin("  ", aux); aux = replace(aux, "  "=>" "); end;
        ln = Base.parse.(Int, split(aux, " "))
        nn = ln[1]                     # Number of nodes
        push!(cells, ln[2:end])
    end


    # Skip empty lines
    ln = skip_empty_lines(f)

    if ln[1:10]!="CELL_TYPES"
        error("Expected to find CELL_TYPES, found $(ln[1:7]).")
    end

    nc2 = Base.parse(Int, split(ln, " ")[2])      # Number of cells again
    if nc != nc2
        error("Found $nc2 cell types but there's $nc cells.")
    end


    # Read cells
    cell_types = Vector{Int}(undef, nc2) #pre-allocate
    for ci in 1:nc2
        cell_types[ci] = Base.parse(Int, readline(f))    # Cell type
    end

    # -------------- DATA FIELDS ------------------------------------------
    data = Dict()

    # Skip empty lines
    ln = skip_empty_lines(f)

    while ln != nothing    # Iterate until end of file

        dataparent = split(ln, " ")[1]  # Parent of this data
        nd = Base.parse(Int, split(ln, " ")[2])   # Number of data entries

        if dataparent == "POINT_DATA"
            if nd != np
                error("Found $nd point data but there's $np points.")
            end


        elseif dataparent == "CELL_DATA"
            if nd != nc
                error("Found $nd cell data but there's $nc cells.")
            end

        else
            error("Found invalid data parent $dataparent."*
                   " Valid types are POINT_DATA and CELL_DATA.")
        end

        if dataparent in keys(data)
            error("LOGIC ERROR: Found data parent $dataparent more than once!")
        end

        data[dataparent] = Dict()

        ln = skip_empty_lines(f)

        # Read datasets until next data parent is encountered
        while ln != nothing && split(ln, " ")[1] in ["SCALARS", "VECTORS"]

            datatype, name, dreal = split(ln, " ")

            if name in keys(data[dataparent])
                error("LOGIC ERROR: Found data name $name more than once!")
            end

            if datatype == "SCALARS"

                entrytype, tag = split(readline(f), " ")

                if entrytype != "LOOKUP_TABLE"
                    error("Only LOOKUP_TABLE currently supported; found $entrytype.")
                end

                this_data = Vector{Float64}(undef, nd) #pre-allocate
                for i in 1:nd
                     this_data[i] = Base.parse(Float64, readline(f))
                end
            elseif datatype == "VECTORS"

                this_data = Array{Float64}(undef, 3, nd) #pre-allocate
                for i in 1:nd
                     this_data[:, i] = Base.parse.(Float64, split(readline(f), " "))
                end

            else
                error("Found invalid data type $datatype."*
                       " Valid types are SCALARS and VECTORS.")
            end

            data[dataparent][name] = this_data

            ln = skip_empty_lines(f)
        end

    end

    close(f)

    return points, cells, cell_types, data
end

"""
  `generateVTK(filename, points; lines, cells, point_data, path, num, time)`

Generates a vtk file with the given data.

  **Arguments**
  * `points::Array{Array{Float64,1},1}`     : Points to output.

  **Optional Arguments**
  * `lines::Array{Array{Int64,1},1}`  : line definitions. lines[i] contains the
                            indices of points in the i-th line.
  * `cells::Array{Array{Int64,1},1}`  : VTK polygons definiton. cells[i]
                            contains the indices of points in the i-th polygon.
  * `data::Array{Dict{String,Any},1}` : Collection of data point fields in the
                            following format:
                              data[i] = Dict(
                                "field_name" => field_name::String
                                "field_type" => "scalar" or "vector"
                                "field_data" => point_data
                              )
                            where point_data[i] is the data at the i-th point.

See `examples.jl` for an example on how to use this function.
"""
function generateVTK(filename::String, points;
                    lines::AbstractVector{Arr1}=Vector{Int}[],
                    cells::AbstractVector{Arr2}=Vector{Int}[],
                    point_data=nothing, cell_data=nothing,
                    num=nothing, time=nothing,
                    path="", comments="", _griddims::Int64=-1,
                    keep_points::Bool=false,
                    override_cell_type::Int64=-1,
                    rnd_d=32) where {N1, N2,
                                     Arr1 <: Union{Vector{Int}, NTuple{N1, Int}},
                                     Arr2 <: Union{Vector{Int}, NTuple{N2, Int}}}

  aux = num!=nothing ? ".$num" : ""
  ext = aux*".vtk"
  if !isfile(path)
    mkpath(path)
  end
  f = open(joinpath(path, filename*ext), "w")

  # HEADER
  header = "# vtk DataFile Version 4.0"  # File version and identifier
  header *= "\n "*comments               # Title
  header *= "\nASCII"                    # File format
  header *= "\nDATASET UNSTRUCTURED_GRID"
  print(f, header)

  # TIME
  if time!=nothing
    line0 = "\nFIELD FieldData 1"
    # line1 = "\nSIM_TIME 1 1 double"
    # line1 = "\nTIME 1 1 double"
    line1 = "\nTimeValue 1 1 double"
    line2 = "\n$(round.(time, digits=rnd_d))"
    print(f, line0, line1, line2)
  end

  np = size(points, 1)
  nl = length(lines)
  nc = length(cells)

  _keep_points = keep_points || (nl==0 && nc==0)

  # POINTS
  print(f, "\n", "POINTS ", np, " float")
  for i in 1:np
    print(f, "\n", round.(points[i][1], digits=rnd_d), " ",
            round.(points[i][2], digits=rnd_d), " ", round.(points[i][3], digits=rnd_d))
  end

  # We do this to avoid outputting points as cells if outputting a Grid
  # or if we simply want to ignore points
  if _griddims!=-1 || !_keep_points
    auxnp = np
    np = 0
  end

  # CELLS
  auxl = length(lines)
  for line in lines
    auxl += length(line)
  end
  auxc = length(cells)
  for cell in cells
    auxc += length(cell)
  end
  print(f, "\n\nCELLS $(np+nl+nc) $(2*np+auxl+auxc)")

  for i in 1:np+nl+nc
    if i<=np
      pts = [i-1]
    elseif i<=np+nl
      pts = lines[i-np]
    else
      pts = cells[i-(nl+np)]
    end
    print(f, "\n", length(pts))
    for pt in pts
      print(f, " ", pt)
    end
  end

  print(f, "\n\nCELL_TYPES $(np+nl+nc)")
  for i in 1:np+nl+nc
    if i<=np
      tpe = 1
    elseif i<=np+nl
      tpe = 4
    else
      if override_cell_type==-1
        if _griddims!=-1
          if _griddims==1
            tpe = 3
          elseif _griddims==2
            tpe = 9
          elseif _griddims==3
            tpe = 12
          else
            error("Generation of VTK cells of $_griddims dimensions not implemented")
          end
        else
          tpe = 7
        end
      else
        tpe = override_cell_type
      end
    end
    print(f, "\n", tpe)
  end

  if _griddims!=-1 || !_keep_points
    np = auxnp
  end

  # POINT DATA
  if point_data!=nothing
      print(f, "\n\nPOINT_DATA $np")
  end
  _p_data = point_data!=nothing ? point_data : []
  for field in _p_data
    field_name = field["field_name"]
    field_type = field["field_type"]
    data = field["field_data"]
    if length(data)!=np
      @warn("Corrupted field $(field_name)! Field size != number of points.")
    end
    if field_type=="scalar"
      print(f, "\n\nSCALARS $field_name float\nLOOKUP_TABLE default")
      for entry in data
        print(f, "\n", round.(entry, digits=rnd_d))
      end
    elseif field_type=="vector"
      print(f, "\n\nVECTORS $field_name float")
      for entry in data
        print(f, "\n", round.(entry[1], digits=rnd_d), " ", round.(entry[2], digits=rnd_d), " ", round.(entry[3], digits=rnd_d))
      end
    else
      error("Unknown field type $(field_type).")
    end
  end


    # CELL DATA
    if cell_data!=nothing
        print(f, "\n\nCELL_DATA $nc")
    end
    _c_data = cell_data!=nothing ? cell_data : []
    for field in _c_data
      field_name = field["field_name"]
      field_type = field["field_type"]
      data = field["field_data"]
      if size(data)[1]!=nc
        @warn("Corrupted field $(field_name)! Field size != number of cells.")
      end
      if field_type=="scalar"
        print(f, "\n\nSCALARS $field_name float\nLOOKUP_TABLE default")
        for entry in data
          print(f, "\n", round.(entry, digits=rnd_d))
        end
      elseif field_type=="vector"
        print(f, "\n\nVECTORS $field_name float")
        for entry in data
          print(f, "\n", round.(entry[1], digits=rnd_d), " ", round.(entry[2], digits=rnd_d), " ", round.(entry[3], digits=rnd_d))
        end
      else
        error("Unknown field type $(field_type).")
      end
    end

  close(f)
  return filename*ext*";"
end
