# master launches all worker and parameter server processes

# list of tuples (worker id, worker process reference, master_recv_channel, master_send_channel)
workers = Tuple{Int, Any, Any, Any}[]

# list of tuples of (param server process id, param server process reference, master_recv_channel, master_send_channel)
paramservers = Tuple{Int, Any, Any, Any}[]

pserver_gradient_update_channel = RemoteChannel(() -> Channel(PABASTO.num_workers * 10), 1);
pserver_update_request_channel = RemoteChannel(() -> Channel(PABASTO.num_workers * 10), 1);

function get_pserver_gradient_update_channel()
	if isready(pserver_gradient_update_channel)
		return take!(pserver_gradient_update_channel)
	else
		return nothing
	end
end

function get_pserver_update_request_channel()
	if isready(pserver_update_request_channel)
		return take!(pserver_update_request_channel)
	else
		return nothing
	end
end

