# Ancillary-data test source: writes one RFC 8331 timecode packet per grain into
# an MXL data flow. Two stages so the runtime image carries libmxl and the binary
# and nothing else.
#
# The go-mxl tag pins both halves. They must match: the builder's headers and the
# runtime's libmxl.so are released together, and mixing them gives a binary that
# links against a different ABI than it runs on.

# renovate: datasource=docker depName=ghcr.io/qvest-digital/go-mxl-builder
ARG GO_MXL_TAG=1.0.0-rc.9

FROM ghcr.io/qvest-digital/go-mxl-builder:${GO_MXL_TAG} AS build

USER 0:0
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY CMakeLists.txt /src/
COPY vendor /src/vendor/
COPY src /src/src/
COPY tests /src/tests/

# go-mxl-builder ships libmxl under /opt/libmxl/lib only, with no multiarch
# symlink, so `-lmxl` does not resolve on its own.
RUN ln -s /opt/libmxl/lib/libmxl.so /usr/lib/x86_64-linux-gnu/libmxl.so \
 && ln -s /opt/libmxl/lib/libmxl-fabrics.so /usr/lib/x86_64-linux-gnu/libmxl-fabrics.so

# ctest runs the framing round-trip here: it needs no MXL domain and no network,
# and the alternative is finding a framing regression from a probe dump on a
# cluster.
RUN cmake -S /src -B /src/build -DCMAKE_BUILD_TYPE=Release \
 && cmake --build /src/build --parallel \
 && ctest --test-dir /src/build --output-on-failure \
 && cmake --install /src/build --prefix /opt/mxl-anc-testsrc

FROM ghcr.io/qvest-digital/go-mxl-runtime:${GO_MXL_TAG}

USER 0:0
COPY --from=build /opt/mxl-anc-testsrc/bin/mxl-anc-testsrc /usr/bin/
WORKDIR /home/mxl
ENTRYPOINT ["/usr/bin/mxl-anc-testsrc"]
