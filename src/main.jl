function add_pabasto_procs(count)
	ids = addprocs(count)
	for id in ids
		remotecall_fetch(()->eval(Main, quote
			if myid() != 1
				redirect_stderr(open("$(myid()).err", "w"))
			end
			using PABASTO
		end), id)
	end
	return ids
end

using PABASTO

# 100 is `some large number' because we can't resize channels
master_channel = RemoteChannel(() -> Channel(101), 1)

master_id = add_pabasto_procs(1)[1]
fetch(@spawnat master_id PABASTO.master(master_channel))

#=
# wait for all workers to finish
for (id, ref, mrc) in workers
	fetch(ref)
end
=#

#=
for (id, ref, mrc) in PABASTO.paramservers
	put!(mrc, PABASTO.CeaseOperationMessage());
end
=#
