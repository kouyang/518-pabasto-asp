function add_pabasto_proc()
	id = addprocs(1)[1]
	remotecall_fetch(()->eval(Main, quote
		using PABASTO
	end), id)
	return id
end

using PABASTO

# 100 is `some large number' because we can't resize channels
master_channel = RemoteChannel(() -> Channel(101), 1)

master_id = add_pabasto_proc()
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
>>>>>>> Move process-spawning from main.jl to master.jl so that it can be done
