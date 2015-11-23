#add m workers and n paramservers
function initialize_nodes(m, n)
	
	new_process_ids=addprocs(n)
	for id in new_process_ids
		#todo: remove wait
		wait(@spawnat id (using PABASTO))
		master_channel = Channel(10);
		remotecall_fetch(id, PABASTO.paramserver, master_channel, nothing, nothing);
		#ref=@spawnat id PABASTO.paramserver(master_channel, nothing, nothing)
		#fetch(ref)
		push!(PABASTO.paramservers,(id, master_channel))
	end
	
	#add logic for dataset division, and pass to PABASTO.worker
	new_process_ids=addprocs(m)
	randy = RandomDevice();
	for id in new_process_ids
		#todo: remove wait
		wait(@spawnat id (using PABASTO))
		master_channel = Channel(10);
		pserver_index = round( rand(randy) * (length(PABASTO.paramservers) - 1) + 1 );
		pserver_index = convert(Int, pserver_index);
		(pserver_id, ~) = PABASTO.paramservers[pserver_index];
		pserver_recv_channel = Channel(10);
		pserver_send_channel = Channel(10);
		remotecall_fetch(pserver_id, PABASTO.update_worker_channels, pserver_recv_channel, pserver_send_channel);
		ref=@spawnat id PABASTO.worker(master_channel, pserver_recv_channel, pserver_send_channel, id, pserver_id)
		push!(PABASTO.workers,(id, ref, pserver_id, master_channel, pserver_recv_channel, pserver_send_channel))
	end
end

using PABASTO
initialize_nodes(3, 1)

#wait for all workers to finish
for (id,ref) in PABASTO.workers
	fetch(ref)
end
