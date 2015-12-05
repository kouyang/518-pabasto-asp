using PABASTO

# list of tuples (worker id, worker process reference, master_recv_channel, master_control_channel)
workers = Tuple{Int, Any, Any, Any}[]

# list of tuples of (param server process id, param server process reference, master_recv_channel)
paramservers = Tuple{Int, Any, Any}[]

# add m workers and n paramservers
function initialize_nodes(m, n, master_channel, pserver_gradient_update_channel, pserver_update_request_channel)
	global workers
	global paramservers
	
	master_id = addprocs(1)[1]
	pserver_ids= addprocs(n)
	worker_ids=addprocs(m)
	@sync @everywhere begin
		if myid() != 1
			redirect_stderr(open("$(myid()).err","w"))
		end
		using PABASTO
	end
	
	for id in pserver_ids
		# todo: remove wait
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		remotecall_fetch(PABASTO.paramserver_setup, id, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel);
		ref = @spawnat id PABASTO.paramserver(master_recv_channel,pserver_gradient_update_channel,pserver_update_request_channel)
		push!(paramservers, (id, ref, master_recv_channel))
	end
	
	for id in worker_ids
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		master_control_channel = RemoteChannel(() -> Channel(10), id);
		pserver_recv_update_channel = RemoteChannel(() -> Channel(10), id);
		ref = @spawnat id PABASTO.worker(id, master_channel, master_recv_channel, master_control_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
		push!(workers, (id, ref, master_recv_channel, master_control_channel))
	end
	
	@spawnat master_id PABASTO.master(master_channel,pserver_gradient_update_channel, pserver_update_request_channel, pserver_ids, worker_ids, paramservers, workers)
	
end

num_workers = 3
num_paramservers = 1
master_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)
pserver_gradient_update_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)
pserver_update_request_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)

initialize_nodes(num_workers, num_paramservers, master_channel, pserver_gradient_update_channel, pserver_update_request_channel)

# wait for all workers to finish
for (id, ref, mrc, mcc) in workers
	fetch(ref)
end
