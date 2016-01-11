using ClusterManagers

all_ids = addprocs(SlurmManager(8))
function add_pabasto_procs(count)
	@assert count <= length(all_ids)
	ids = all_ids[1:count]
	global all_ids = all_ids[count+1:end]
	refs=[remotecall(()->eval(Main, quote
		if myid() != 1
			#redirect_stderr(open("$(myid()).err", "w"))
			#redirect_stdout(open("$(myid()).out", "w"))
		end
		using PABASTO
	end), id)
	for id in ids
	]
	for ref in refs
		wait(ref)
	end
	return ids
end

using PABASTO

master_id = add_pabasto_procs(1)[1]
fetch(@spawnat master_id PABASTO.master())
