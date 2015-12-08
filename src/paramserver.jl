### Param Server State ###
type ParamServerState
	params
	master_mailbox
	pserver_mailbox
end

local_state = nothing

function paramserver_setup(master_mailbox, pserver_mailbox)
	global local_state
	params = SimpleParameter(Any[PABASTO.dummy_weights1,PABASTO.dummy_biases1]);
	local_state = ParamServerState(params, master_mailbox, pserver_mailbox);
end

#Need to decide if paramservers will spin
#=
function paramserver()
	while true
		if isready(master_mailbox) # wrong
			msg = take!(state.master_mailbox)
			if typeof(msg) == CeaseOperationMessage
				println("[PARAM SERVER] Param server $(id) is shutting down")
				return
			end
		end

		output1 = remotecall_fetch(get_pserver_gradient_update_channel, 1)
		output2 = remotecall_fetch(get_pserver_update_request_channel, 1)

		if output2 != nothing
			worker_mailbox = output2.worker_mailbox;
			put!(worker_mailbox, SendParameterUpdateMessage(SimpleParameter()))
			println("[PARAM SERVER] Parameter update message has been sent to worker")
		end
	end
end
=#

function handle(message::ParameterUpdateRequestMessage)
	global local_state
	println("[PARAM SERVER] Reading params")
	put!(message.worker_mailbox,ParameterUpdateMessage(local_state.params))
end

function handle(message::GradientUpdateMessage)
	global local_state
	println("[PARAM SERVER] Writing params")
	update(local_state.params, message.gradient)
end

function handle(message::InitiateGossipMessage)
	global local_state
	println("[PARAM SERVER] Initiating gossip")
	remotecall(handle, message.pserver_id, ParameterGossipMessage(local_state.params));
end

function handle(message::ParameterGossipMessage)
	global local_state
	println("[PARAM SERVER] Performing gossip average")
	local_state.params = gossip_average(local_state.params, message.parameters);
end
