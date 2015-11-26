# add m workers and n paramservers
function initialize_nodes(m, n, pserver_gradient_update_channel, pserver_update_request_channel)
	master_id = addprocs(1)[1]
	@spawnat master_id PABASTO.master()

	new_process_ids = addprocs(n)
	for id in new_process_ids
		# todo: remove wait
		wait(@spawnat id (using PABASTO))
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		remotecall_fetch(PABASTO.paramserver_setup, id, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel);
		ref = @spawnat id PABASTO.paramserver()
		push!(PABASTO.paramservers, (id, ref, master_recv_channel))
	end

	# add logic for dataset division, and pass to PABASTO.worker
	new_process_ids = addprocs(m)
	randy = RandomDevice();
	for id in new_process_ids
		PABASTO.add_worker_hash(id)
	end
	PABASTO.partition_examples()

	for id in new_process_ids
		# todo: remove wait
		wait(@spawnat id (using PABASTO))
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		pserver_recv_update_channel = RemoteChannel(() -> Channel(10), id);
		ref = @spawnat id PABASTO.worker(id, PABASTO.master_channel, master_recv_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
		push!(PABASTO.workers, (id, ref, master_recv_channel))
	end
end

using PABASTO
initialize_nodes(PABASTO.num_workers, PABASTO.num_paramservers, PABASTO.pserver_gradient_update_channel, PABASTO.pserver_update_request_channel)

# wait for all workers to finish
for (id, ref, mrc) in PABASTO.workers
	fetch(ref)
end

#=
for (id, ref, mrc) in PABASTO.paramservers
	put!(mrc, PABASTO.CeaseOperationMessage());
end
=#