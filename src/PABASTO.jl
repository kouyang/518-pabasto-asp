module PABASTO

###Parameters###
abstract Parameter
abstract Gradient
type ConcreteParameter <: Parameter
	#fill me
end

type ConcreteGradient <: Gradient
	#fill me
end

function update(p::ConcreteParameter,g::ConcreteGradient)
	#update p with parameter g
end

#todo: split into separate modules
include("master.jl")
include("worker.jl")
include("paramserver.jl")

end
