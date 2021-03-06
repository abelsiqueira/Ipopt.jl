using BinDeps
using Compat

@BinDeps.setup

windllname = "libipopt-1"
libipopt = library_dependency("libipopt", aliases=[windllname])

ipoptname = "Ipopt-3.12.1"

provides(Sources, URI("http://www.coin-or.org/download/source/Ipopt/$ipoptname.tgz"),
    libipopt, os = :Unix)

prefix=joinpath(BinDeps.depsdir(libipopt),"usr")
patchdir=BinDeps.depsdir(libipopt)
srcdir = joinpath(BinDeps.depsdir(libipopt),"src",ipoptname)

# fpu_control flag for building on ARM
if Sys.ARCH == :arm
    fpu_control = "ADD_CFLAGS=-DNO_fpu_control"
else
    fpu_control = ""
end

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libipopt)
        @build_steps begin
            ChangeDirectory(srcdir)
            @build_steps begin
                ChangeDirectory(joinpath(srcdir,"ThirdParty","Blas"))
                CreateDirectory("build", true)
                `sed -i.backup 's/wget"/wget --no-check-certificate"/g' get.Blas`
                `./get.Blas`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir,"ThirdParty","Blas","build"))
                `../configure --prefix=$prefix --disable-shared --with-pic`
                `make install`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir,"ThirdParty","Lapack"))
                CreateDirectory("build", true)
                `sed -i.backup 's/wget"/wget --no-check-certificate"/g' get.Lapack`
                `./get.Lapack`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir,"ThirdParty","Lapack","build"))
                `../configure --prefix=$prefix --disable-shared --with-pic
                              --with-blas="$prefix/lib/libcoinblas.a -lgfortran"`
                `make install`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir,"ThirdParty","ASL"))
                `./get.ASL`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir,"ThirdParty","Mumps"))
                `./get.Mumps`
            end
            `./configure --prefix=$prefix coin_skip_warn_cxxflags=yes
                         --with-blas="$prefix/lib/libcoinblas.a -lgfortran"
                         --with-lapack=$prefix/lib/libcoinlapack.a
                         $fpu_control`
            `make`
            `make test`
            `make -j1 install`
        end
    end),libipopt, os = :Unix)

# OS X
if is_apple()
    using Homebrew
    provides(Homebrew.HB, "staticfloat/juliadeps/ipopt", libipopt, os = :Darwin)
end

# Windows
if is_windows()
    using WinRPM
    provides(WinRPM.RPM, "Ipopt", [libipopt], os = :Windows)
end

# Avoid Issue #62, building into /lib64 on OpenSUSE
configsite = nothing
if haskey(ENV, "CONFIG_SITE")
    configsite = pop!(ENV, "CONFIG_SITE")
end

@BinDeps.install Dict(:libipopt => :libipopt)

if configsite !== nothing
    ENV["CONFIG_SITE"] = configsite
end
