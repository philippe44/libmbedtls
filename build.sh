#!/bin/bash

list="x86_64-linux-gnu-gcc x86-linux-gnu-gcc arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc \
      sparc64-linux-gnu-gcc mips-linux-gnu-gcc powerpc-linux-gnu-gcc x86_64-macos-darwin-gcc \
      arm64-macos-darwin-cc x86_64-freebsd-gnu-gcc x86_64-solaris-gnu-gcc armv6-linux-gnueabi-gcc \
	  armv5-linux-gnueabi-gcc"

declare -A alias=( [x86-linux-gnu-gcc]=i686-stretch-linux-gnu-gcc \
                   [x86_64-linux-gnu-gcc]=x86_64-stretch-linux-gnu-gcc \
                   [arm-linux-gnueabi-gcc]=armv7-stretch-linux-gnueabi-gcc \
                   [armv5-linux-gnueabi-gcc]=armv6-stretch-linux-gnueabi-gcc \
                   [armv6-linux-gnueabi-gcc]=armv6-stretch-linux-gnueabi-gcc \
                   [aarch64-linux-gnu-gcc]=aarch64-stretch-linux-gnu-gcc \
                   [sparc64-linux-gnu-gcc]=sparc64-stretch-linux-gnu-gcc \
                   [mips-linux-gnu-gcc]=mips64-stretch-linux-gnu-gcc \
                   [powerpc-linux-gnu-gcc]=powerpc64-stretch-linux-gnu-gcc \
                   [x86_64-macos-darwin-gcc]=x86_64-apple-darwin19-gcc \
                   [arm64-macos-darwin-cc]=arm64-apple-darwin20.4-cc \
                   [x86_64-freebsd-gnu-gcc]=x86_64-cross-freebsd12.3-gcc \
                   [x86_64-solaris-gnu-gcc]=x86_64-cross-solaris2.x-gcc )

declare -A cflags=( [sparc64-linux-gnu-gcc]="-mcpu=v7" \
                    [mips-linux-gnu-gcc]="-march=mips32" \
                    [armv5-linux-gnueabi-gcc]="-march=armv5t -mfloat-abi=soft" \
                    [powerpc-linux-gnu-gcc]="-m32" \
	    )
             #       [x86_64-solaris-gnu-gcc]=-mno-direct-extern-access )
					
declare -a compilers					

IFS= read -ra candidates <<< "$list"

# do we have "clean" somewhere in parameters (assuming no compiler has "clean" in it...)
if [[ $@[*]} =~ clean ]]; then
	clean="clean"
fi	

# first select platforms/compilers
for cc in ${candidates[@]}; do
	# check compiler first
	if ! command -v ${alias[$cc]:-$cc} &> /dev/null; then
		if command -v $cc &> /dev/null; then
			unset alias[$cc]
		else	
			continue
		fi	
	fi

	if [[ $# == 0 || ($# == 1 && -n $clean) ]]; then
		compilers+=($cc)
		continue
	fi

	for arg in $@
	do
		if [[ $cc =~ $arg ]]; then 
			compilers+=($cc)
		fi
	done
done

pwd=$(pwd)
library=_libmbedtls.a

# then iterate selected platforms/compilers
for cc in ${compilers[@]}
do
	IFS=- read -r platform host dummy <<< $cc

	build=mbedtls/build/$host-$platform
	target=targets/$host/$platform
		
	mkdir -p $build && cd $build || continue

	export CFLAGS=${cflags[$cc]}
	export CC=${alias[$cc]:-$cc} 
	export CXX=${CC/gcc/g++}
	export AR=${CC%-*}-ar
	export RANLIB=${CC%-*}-ranlib

	if [ -n "$clean" ] || [ -z "$(ls -A)" ]; then
		rm -r *
		cmake $pwd/mbedtls -DCMAKE_C_COMPILER=$CC -DENABLE_TESTING=OFF -DENABLE_PROGRAMS=OFF
	fi
	
	make -j16
	cd $pwd

	# copy and concatenate all in a thin (if possible)
	rm -rf $target
    mkdir -p $_  
	cp -u $build/library/*.a $_

	rm -f $target/$library
	if [[ $host =~ macos ]]; then
		# libtool will whine about duplicated symbols
		${CC%-*}-libtool -static -o $target/$library $target/*.a
	else
		ar -rc --thin $target/$library $target/*.a
	fi
done

# includes are common
mkdir -p targets/include
cp -ur mbedtls/include/* $_
find $_ -type f -not -name "*.h" -exec rm {} +
