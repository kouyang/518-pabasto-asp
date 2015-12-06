using PABASTO

# list of tuples (worker id, worker process reference, master_recv_channel, master_control_channel)
workers = Tuple{Int, Any, Any}[]

# list of tuples of (param server process id, param server process reference, master_recv_channel)
paramservers = Tuple{Int, Any, Any}[]

# add m workers and n paramservers
function initialize_nodes(m, n, master_mailbox)
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
		pserver_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		ref = @spawnat id PABASTO.paramserver_setup(master_mailbox,pserver_mailbox)
		push!(paramservers, (id, ref, pserver_mailbox))
	end

	for (id,ref,mailbox) in paramservers
		wait(ref)
	end
	
	for id in worker_ids
		worker_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), id)
		ref = @spawnat id PABASTO.worker(id, master_mailbox,worker_mailbox)
		push!(workers, (id, ref, worker_mailbox))
	end
	
	@spawnat master_id PABASTO.master(master_mailbox, paramservers, workers)
	
end

num_workers = 3
num_paramservers = 1
master_mailbox = RemoteChannel(() -> PABASTO.Mailbox(), 1)

initialize_nodes(num_workers, num_paramservers, master_mailbox)

# wait for all workers to finish
for (id, ref, mailbox) in workers
	fetch(ref)
end
