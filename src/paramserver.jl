###Param Server State###
type ParamServerState
	params
	master_channel
	worker_recv_channels
	worker_send_channels
end

local_state=nothing

#main paramserver loop
function paramserver(master_channel, worker_recv_channels, worker_send_channels)
	global local_state = ParamServerState(ConcreteParameter(), master_channel, worker_recv_channels, worker_send_channels)
end

function update_worker_channels(worker_recv_channel, worker_send_channel)
	global local_state
	local_state.worker_recv_channels = [local_state.worker_recv_channels; worker_recv_channel];
	local_state.worker_send_channels = [local_state.worker_send_channels; worker_send_channel];
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
