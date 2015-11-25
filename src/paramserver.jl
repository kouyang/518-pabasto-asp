### Param Server State ###
type ParamServerState
	params
	master_recv_channel
	master_send_channel
	pserver_gradient_update_channel
	pserver_update_request_channel
end

local_state = nothing

# main paramserver loop
function paramserver_setup(master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel)
	global local_state = ParamServerState(ConcreteParameter(), master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel)
end

function paramserver()
	while true
		#=
		boo1 = isready(master_recv_channel);
		if boo1
			break
		end
		=#
		
		output1 = remotecall_fetch(get_pserver_gradient_update_channel, 1);
		output2 = remotecall_fetch(get_pserver_update_request_channel, 1);
		
		if output2 != nothing
			channel = output2.worker_recv_channel;
			put!(channel, SendParameterUpdateMessage(ConcreteParameter()));
			println("Parameter update message has been sent to worker");
		end
	end
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