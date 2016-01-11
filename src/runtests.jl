using CIFAR
using Base.Test

# write your own tests here
println("Running Tests...")

info("Normalize! Test")
a = [1 2 3 4 5 6 7 8 9 10;1 2 3 4 5 6 7 8 9 10]';
a = CIFAR.normalize(a);
println(a)


info("Label Names:")
println(CIFAR.labelnames())
info("Loading Batch 1")
  @time D,L,LN = traindata(1)
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))


info("Loading Batch 1 (Grey)")
  @time D,L,LN = traindata(1;grey=true)
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))

info("Loading Batch 1 (Normalize)")
  @time D,L,LN = traindata(1;normalize_images=true)
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))

info("Loading Batch 2")
@time D,L,LN = traindata(2)
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))

info("Loading Batch 3")
@time D,L,LN = traindata(3)
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))

info("Loading Batch 4")
@time D,L,LN = traindata(4)
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))

info("Loading Batch 5")
@time D,L,LN = traindata(5)
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))

info("Loading Test Batch")
@time D,L,LN = testdata()
  print(typeof(D)); print(": "); println(size(D))
  print(typeof(L)); print(": "); println(size(L))
  print(typeof(LN)); print(": "); println(size(LN))

