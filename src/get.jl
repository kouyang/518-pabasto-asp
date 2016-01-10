function download()
  # File Names 
  DataDir = joinpath(dirname(@__FILE__),"data")
  CompressFile = joinpath(DataDir,"bindata.tar.gz")
  CifarOrigDir = joinpath(DataDir,"cifar-10-batches-bin")
  CifarFinalDir = joinpath(DataDir,"bin")

  # Download Compressed Files
  download("http://www.cs.toronto.edu/~kriz/cifar-10-binary.tar.gz",CompressFile)

  # Decompress Dataset
  cd(DataDir)
  run(`tar -zxvf $CompressFile`)
  rm(CompressFile)

  # Rename decompressed directory (for ease)
  mv(CifarOrigDir,CifarFinalDir;remove_destination=true)  
end