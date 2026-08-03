cmake_minimum_required(VERSION 3.20)
project(mxl-anc-testsrc CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# No GStreamer and no pkg-config: this writes ancillary data straight through
# libmxl, so the only dependency is libmxl itself. The runtime .so comes from the
# go-mxl base images; the headers are vendored under vendor/ the same way.
add_executable(mxl-anc-testsrc src/anc_testsrc.cpp)
target_compile_options(mxl-anc-testsrc PRIVATE -Wall -Wextra -Wpedantic)
target_include_directories(mxl-anc-testsrc PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/vendor)
target_link_libraries(mxl-anc-testsrc PRIVATE mxl pthread)

install(TARGETS mxl-anc-testsrc RUNTIME DESTINATION bin)

# The framing round-trip. It links neither libmxl nor anything else -- the RFC
# 8331 builder and parser in src/anc_frame.h are pure bit twiddling -- so it runs
# anywhere, and ctest runs it during the image build. C++20 because the parser
# transcribed from libmxl's mxl-data-probe uses std::span.
enable_testing()
add_executable(anc-frame-test tests/anc_frame_test.cpp)
target_compile_features(anc-frame-test PRIVATE cxx_std_20)
target_compile_options(anc-frame-test PRIVATE -Wall -Wextra -Wpedantic)
add_test(NAME anc-frame COMMAND anc-frame-test)
