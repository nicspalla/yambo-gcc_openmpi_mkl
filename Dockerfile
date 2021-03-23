ARG container_version=20.04
FROM ubuntu:${container_version}

LABEL author="Nicola Spallanzani - nicola.spallanzani@nano.cnr.it - S3 centre, CNR-NANO"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -yqq update \
 && apt-get -yqq install --no-install-recommends \
        build-essential ca-certificates curl file \
        make gcc g++ gfortran \
        git gnupg2 iproute2 lmod \
        locales lua-posix \
        python3 python3-pip python3-setuptools \
        tcl unzip m4 wget git zlib1g-dev ssh \
 && apt-get clean \
 && locale-gen en_US.UTF-8 \
 && pip3 install boto3

ENV SPACK_ROOT=/opt/spack \
    PATH=/opt/spack/bin:$PATH

RUN cd /opt && git clone https://github.com/spack/spack.git && cd spack && git checkout releases/v0.16 && . ${SPACK_ROOT}/share/spack/setup-env.sh \
 && spack install openmpi@4.0.2 %gcc@9.3.0 \
 && cd /opt && ln -s `ls -d /opt/spack/opt/spack/linux-ubuntu20.04-*/gcc-*/openmpi-4.0.2-*` openmpi \
 && spack install intel-mkl && ln -s `ls -d /opt/spack/opt/spack/linux-ubuntu20.04-*/gcc-*/intel-mkl*` mkl

WORKDIR /tmpdir

### YAMBO ###
ARG yambo_version=5.0.0
RUN . ${SPACK_ROOT}/share/spack/setup-env.sh && spack load openmpi@4.0.2 && spack load intel-mkl \
 && wget https://github.com/yambo-code/yambo/archive/${yambo_version}.tar.gz -O yambo-${yambo_version}.tar.gz \
 && tar zxf yambo-${yambo_version}.tar.gz && cd yambo-${yambo_version} \
 && ./configure --enable-open-mp --enable-msgs-comps --enable-time-profile --enable-memory-profile --enable-netcdf-hdf5 --enable-par-linalg \
    --with-blas-libs="-L${MKLROOT}/lib/intel64 -Wl,--no-as-needed -lmkl_gf_lp64 -lmkl_gnu_thread -lmkl_core -lgomp -lpthread -lm -ldl" \
    --with-lapack-libs="-L${MKLROOT}/lib/intel64 -Wl,--no-as-needed -lmkl_gf_lp64 -lmkl_gnu_thread -lmkl_core -lgomp -lpthread -lm -ldl" \
 && make ext-libs && make -j4 yambo && make interfaces ypp \
 && mkdir -p /usr/local/yambo-${yambo_version}/lib \
 && cp -r bin /usr/local/yambo-${yambo_version}/. \
 && cp -r lib/external/*/*/lib/*.* /usr/local/yambo-${yambo_version}/lib/. \
 && cp -r lib/external/*/*/v4/serial/lib/*.* /usr/local/yambo-${yambo_version}/lib/. \
 && cd .. && rm -rf yambo-${yambo_version} yambo-${yambo_version}.tar.gz

ENV PATH=/usr/local/yambo-${yambo_version}/bin:/opt/openmpi/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/yambo-${yambo_version}/lib:/opt/mkl/compilers_and_libraries/linux/mkl/lib/intel64:/opt/openmpi/lib:$LD_LIBRARY_PATH
