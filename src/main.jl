# add m workers and n paramservers
function initialize_nodes(m, n, master_channel, pserver_gradient_update_channel, pserver_update_request_channel)
	master_id = addprocs(1)[1]
	pserver_ids= addprocs(n)
	worker_ids=addprocs(m)
	@sync @everywhere begin
		using PABASTO
	end

	@spawnat master_id PABASTO.master(master_channel)

	for id in pserver_ids
		# todo: remove wait
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		remotecall_fetch(PABASTO.paramserver_setup, id, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel);
		ref = @spawnat id PABASTO.paramserver()
		push!(PABASTO.paramservers, (id, ref, master_recv_channel))
	end

	# add logic for dataset division, and pass to PABASTO.worker
	randy = RandomDevice();

	for id in worker_ids
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		pserver_recv_update_channel = RemoteChannel(() -> Channel(10), id);
		ref = @spawnat id PABASTO.worker(id, master_channel, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
		push!(PABASTO.workers, (id, ref, master_recv_channel))
	end
end

num_workers = 3
num_paramservers = 1
master_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)
pserver_gradient_update_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)
pserver_update_request_channel = RemoteChannel(() -> Channel(num_workers * 10), 1)

using PABASTO
initialize_nodes(num_workers, num_paramservers, master_channel, pserver_gradient_update_channel, pserver_update_request_channel)

# wait for all workers to finish
for (id, ref, mrc) in PABASTO.workers
	fetch(ref)
end

#=
for (id, ref, mrc) in PABASTO.paramservers
	put!(mrc, PABASTO.CeaseOperationMessage());
end
=#
