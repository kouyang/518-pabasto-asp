### Param Server State ###
type ParamServerState
	params
	master_mailbox
	pserver_mailbox
end

local_state = nothing

function paramserver_setup(master_mailbox, pserver_mailbox)
	global local_state = ParamServerState(SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]),master_mailbox,pserver_mailbox)
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
	put!(message.worker_recv_channel,ParameterUpdateMessage(local_state.params))
end

function handle(message::GradientUpdateMessage)
	global local_state
	println("[PARAM SERVER] Writing params")
	update(local_state.params, message.gradient)
end
