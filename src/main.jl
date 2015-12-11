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

master_id = add_pabasto_procs(1)[1]
fetch(@spawnat master_id PABASTO.master())
