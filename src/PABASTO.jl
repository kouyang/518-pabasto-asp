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

type GradientUpdateMessage
	gradient::ConcreteGradient
end

type ParameterUpdateRequestMessage
	worker_recv_channel::RemoteChannel
end

type SendParameterUpdateMessage
	parameter::ConcreteParameter
end

type CeaseOperationMessage
end

function update(p::ConcreteParameter,g::ConcreteGradient)
	#update p with parameter g
end

#todo: split into separate modules
include("master.jl")
include("worker.jl")
include("paramserver.jl")

end
