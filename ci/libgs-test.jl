# Load libgs the way GMT.jl does (ccall into gsapi_*) and run the bbox device.
# usage: julia ci/libgs-test.jl <path-to-libgs> <file.ps>
using Libdl

struct GsRevision
    product::Cstring
    copyright::Cstring
    revision::Clong
    revisiondate::Clong
end

lib, ps = ARGS
h = dlopen(lib)

rev = Ref{GsRevision}()
ccall(dlsym(h, :gsapi_revision), Cint, (Ref{GsRevision}, Cint), rev, sizeof(GsRevision)) == 0 ||
    error("gsapi_revision failed")
println(unsafe_string(rev[].product), " ", rev[].revision)

inst = Ref{Ptr{Cvoid}}(C_NULL)
ccall(dlsym(h, :gsapi_new_instance), Cint, (Ref{Ptr{Cvoid}}, Ptr{Cvoid}), inst, C_NULL) == 0 ||
    error("gsapi_new_instance failed")
ccall(dlsym(h, :gsapi_set_arg_encoding), Cint, (Ptr{Cvoid}, Cint), inst[], 1)     # UTF-8
args = ["gs", "-q", "-dNOPAUSE", "-dBATCH", "-dSAFER", "-sDEVICE=bbox", ps]
code = ccall(dlsym(h, :gsapi_init_with_args), Cint, (Ptr{Cvoid}, Cint, Ptr{Ptr{UInt8}}),
             inst[], length(args), args)
ccall(dlsym(h, :gsapi_exit), Cint, (Ptr{Cvoid},), inst[])
ccall(dlsym(h, :gsapi_delete_instance), Cvoid, (Ptr{Cvoid},), inst[])
(code == 0 || code == -101) || error("gsapi_init_with_args returned $code")
println("libgs test OK")
