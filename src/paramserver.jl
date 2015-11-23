###Param Server State###
type ParamServerState
	params
	master_recv_channel
	master_send_channel
	pserver_gradient_update_channel
	pserver_update_request_channel
end

local_state=nothing

#main paramserver loop
function paramserver(master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel)
	global local_state = ParamServerState(ConcreteParameter(), master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel)
end

function write_params(gradient::Gradient)
	global local_state
	println("writing params")
	update(local_state.params, gradient)
end

function read_params()
	global local_state
	println("reading params")
	return local_state.params
end