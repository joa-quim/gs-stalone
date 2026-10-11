# Write the Artifacts.toml entries (one per platform) for the release tarballs,
# ready to paste into GMT.jl.
# usage: julia ci/artifacts-toml.jl <dir-with-tarballs> <release-base-url> > Artifacts.toml
using Tar, SHA

const PLATFORMS = Dict(
    "windows-x86_64"  => ("x86_64",  "windows", ""),
    "linux-x86_64"    => ("x86_64",  "linux",   "glibc"),
    "linux-aarch64"   => ("aarch64", "linux",   "glibc"),
    "macos-x86_64"    => ("x86_64",  "macos",   ""),
    "macos-aarch64"   => ("aarch64", "macos",   ""),
)

dir, baseurl = ARGS
for f in sort(filter(endswith(".tar.gz"), readdir(dir)))
    path = joinpath(dir, f)
    m = match(r"^gs-[0-9.]+-(.+)\.tar\.gz$", f)
    m === nothing && continue
    arch, os, libc = PLATFORMS[m[1]]
    treehash = open(io -> Tar.tree_hash(io), pipeline(`gzip -dc $path`))
    sha = bytes2hex(open(sha256, path))
    println("[[ghostscript]]")
    println("arch = \"$arch\"")
    println("os = \"$os\"")
    isempty(libc) || println("libc = \"$libc\"")
    println("git-tree-sha1 = \"$treehash\"")
    println()
    println("    [[ghostscript.download]]")
    println("    url = \"$baseurl/$f\"")
    println("    sha256 = \"$sha\"")
    println()
end
