###Param Server State###
type ParamServerState
	params
end

local_state=ParamServerState(ConcreteParameter())

#main paramserver loop
function write_params(gradient::Gradient)
	println("writing params")
	update(local_state.params,gradient)
end

function read_params()
	println("reading params")
	return local_state.params
end
