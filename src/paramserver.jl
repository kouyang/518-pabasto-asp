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

#Need to decide if paramservers will spin
#=
function paramserver()
	while true
		if isready(master_recv_channel)
			msg = take!(state.master_recv_channel)
			if typeof(msg) == CeaseOperationMessage
				println("[PARAM SERVER] Param server $(id) is shutting down")
				return
			end
		end

		output1 = remotecall_fetch(get_pserver_gradient_update_channel, 1)
		output2 = remotecall_fetch(get_pserver_update_request_channel, 1)

		if output2 != nothing
			channel = output2.worker_recv_channel;
			put!(channel, SendParameterUpdateMessage(ConcreteParameter()))
			println("[PARAM SERVER] Parameter update message has been sent to worker")
		end
	end
end
=#

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
