### Param Server State ###
type ParamServerState
	params
	master_recv_channel
	pserver_gradient_update_channel
	pserver_update_request_channel
end

local_state = nothing

# main paramserver loop
function paramserver_setup(master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel)
	global local_state = ParamServerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]), master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel)
end

type ParameterUpdateRequestMessage
	worker_recv_channel::RemoteChannel
end

type SendParameterUpdateMessage
	parameter::ConcreteParameter
end
function handle(message::ParameterUpdateRequestMessage)
	global local_state
	println("[PARAM SERVER] Reading params")
	put!(message.worker_recv_channel,local_state.params)
end

function handle(message::GradientUpdateMessage)
	global local_state
	println("[PARAM SERVER] Writing params")
	update(local_state.params, message.gradient)
end
