module Whistler

export countwhistles

import Tables
import Unitful: Mass, Time, @u_str, ustrip, unit
using REPL.TerminalMenus

"""
```julia
    water #amount of water
    start #start time
    up #when was the temp increased
    down #when did the temp go down
    whistle #when did we get whistles
    missed #when did we miss whistles
    stop #when did the run end
```
"""
struct Whistle
    water::Mass #amount of water
    start::Time #start time
    up::Vector{Time} #when was the temp increased
    down::Vector{Time} #when did the temp go down
    whistle::Vector{Time} #when did we get whistles
    missed::Vector{Time} #when did we miss whistles
    stop::Time #when did the run end
end

function Whistle(;water,
                 start,
                 up=[],
                 down=[],
                 whistle=[],
                 missed=[],
                 stop)
    @assert length(water)==1
    @assert length(start)==1
    @assert length(stop)==1
    Whistle(water[1],
            start[1],
            up,
            down,
            whistle,
            missed,
            stop[1])
end

#units to use when saving or loading Whistles from Tables.jl
tableunits=Dict(
    :water => 1*u"g",
    :start => 1*u"s",
    :up => 1*u"s",
    :down => 1*u"s",
    :whistle => 1*u"s",
    :missed => 1*u"s",
    :stop => 1*u"s"
)

"""
```julia
Whistle(t)
```

Create a `Whistle` object from a `Tables.jl` table
"""
function Whistle(t)
    @assert Tables.istable(t)
    args=Dict()
    for row in Tables.rows(t)
        event=Tables.getcolumn(row,:event) |> Symbol
        entry=Tables.getcolumn(row,:entry)
        #annotate with our default units
        quant=entry*tableunits[Symbol(event)]
        try
            push!(args[event],quant)
        catch e
            if e isa KeyError #key event doesn't exist
                args[event]=[quant]
            end
        end
    end

    Whistle(;args...)
    
end

Tables.istable(::Type{Whistle}) = true

Tables.rowaccess(::Type{Whistle}) = true

function Tables.rows(w::Whistle)
    #get all the events converted to the units specified by tableunits
    table=[]
    for p in propertynames(w)
        this_prop=getproperty(w,p)
        if this_prop isa Vector
            for t in ustrip.(unit(tableunits[p]),this_prop)
                push!(table,(event=String(p),entry=t))
            end
        else
            push!(table,(event=String(p),entry=ustrip(unit(tableunits[p]),
                                              this_prop)))
        end
    end
    
    #sort them by time
    perm=sortperm(collect(row.entry for row in table))

    #return an iterator of our sorted rows
    (table[i] for i in perm)
end

function countwhistles()
    println("Enter the amount of water used in grams")
    water=parse(Float64,readline())u"g"
    utime() = time()u"s" #make a little function to annotate with u"s"
    println("press enter to start run")
    readline()
    start=utime()
    stop=nothing
    up=[]
    down=[]
    whistle=[]
    missed=[]
    while true
        println("What happened")
        baseevent=request(RadioMenu(["Whistle",
                                     "Missed Whistle",
                                     "Temperature Change",
                                     "Stop"]))
        if baseevent == 1 #whistle
            push!(whistle,utime())
        elseif baseevent == 2 #missed whistle
            push!(missed,utime())
        elseif baseevent == 3 #temp change
            tempevent=request(RadioMenu(["Up","Down"]))
            if tempevent==1 #up
                push!(up,utime())
            elseif tempevent==2 #down
                push!(down,utime())
            end
        elseif baseevent == 4 #stop
            stop=utime()
            break
        end     
    end
    Whistle(water,start,up,down,whistle,missed,stop)
end

end # module Whistler
