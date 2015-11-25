# add m workers and n paramservers
function initialize_nodes(m, n, pserver_gradient_update_channel, pserver_update_request_channel)
	new_process_ids = addprocs(n)
	for id in new_process_ids
		# todo: remove wait
		wait(@spawnat id (using PABASTO))
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		master_send_channel = RemoteChannel(() -> Channel(10), id);
		remotecall_fetch(PABASTO.paramserver_setup, id, master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel);
		ref = @spawnat id PABASTO.paramserver()
		push!(PABASTO.paramservers, (id, ref, master_recv_channel, master_send_channel))
	end
	
	# add logic for dataset division, and pass to PABASTO.worker
	new_process_ids = addprocs(m)
	randy = RandomDevice();
	for id in new_process_ids
		# todo: remove wait
		wait(@spawnat id (using PABASTO))
		master_recv_channel = RemoteChannel(() -> Channel(10), id);
		master_send_channel = RemoteChannel(() -> Channel(10), id);
		pserver_recv_update_channel = RemoteChannel(() -> Channel(10), id);
		ref = @spawnat id PABASTO.worker(master_recv_channel, master_send_channel, pserver_gradient_update_channel, pserver_update_request_channel, pserver_recv_update_channel)
		push!(PABASTO.workers, (id, ref, master_recv_channel, master_send_channel))
	end
end

using PABASTO
m = 3;
n = 1;

initialize_nodes(m, n, PABASTO.pserver_gradient_update_channel, PABASTO.pserver_update_request_channel)

# wait for all workers to finish
for (id, ref, mrc, msc) in PABASTO.workers
	fetch(ref)
end

#=
for (id, ref, mrc, msc) in PABASTO.paramservers
	put!(mrc, PABASTO.CeaseOperationMessage());
end
=#