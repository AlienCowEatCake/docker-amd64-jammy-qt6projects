FROM ubuntu:22.04

RUN groupadd --gid 1000 user && \
    useradd --shell /bin/bash --home-dir /home/user --uid 1000 --gid 1000 --create-home user

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get -o Acquire::Check-Valid-Until=false --yes --allow-unauthenticated dist-upgrade && \
    apt-get -o Acquire::Check-Valid-Until=false install --yes --allow-unauthenticated --no-install-recommends \
        wget build-essential fakeroot debhelper curl gawk chrpath git openssh-client p7zip-full libssl-dev \
        "^libxcb.*-dev" libxkbcommon-dev libxkbcommon-x11-dev libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev \
        libdbus-1-dev libglib2.0-dev libfreetype6-dev libcups2-dev mesa-common-dev libgl1-mesa-dev libegl1-mesa-dev \
        libxcursor-dev libxcomposite-dev libxdamage-dev libxrandr-dev libfontconfig1-dev libxss-dev libxtst-dev \
        libpulse-dev libasound2-dev libva-dev libopenal-dev libbluetooth-dev libspeechd-dev \
        libgtk-3-dev libgtk2.0-dev gperf bison ruby flex yasm libwayland-dev libwayland-egl-backend-dev \
        libgstreamer-plugins-base1.0-dev libgstreamer-plugins-good1.0-dev libgstreamer-plugins-bad1.0-dev \
        libgstreamer1.0-dev flite1-dev libvulkan-dev gsettings-desktop-schemas gcc-12 g++-12 && \
    apt-get clean

WORKDIR /usr/src

ENV PATH="/opt/clang/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/clang/lib:/opt/qt6/lib:/opt/icu/lib"
ENV LANG="C.UTF-8"

RUN export CMAKE_VERSION="4.2.2" && \
    wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xvpf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./configure --prefix=/opt/cmake --no-qt-gui --parallel=$(getconf _NPROCESSORS_ONLN) && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    ln -s /opt/cmake/bin/cmake /usr/local/bin/ && \
    ln -s /opt/cmake/bin/ctest /usr/local/bin/ && \
    ln -s /opt/cmake/bin/cpack /usr/local/bin/ && \
    cd .. && \
    rm -rf cmake-${CMAKE_VERSION}.tar.gz cmake-${CMAKE_VERSION}

RUN export NINJA_VERSION="1.13.2" && \
    wget --no-check-certificate https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VERSION}.tar.gz && \
    tar -xvpf v${NINJA_VERSION}.tar.gz && \
    cd ninja-${NINJA_VERSION} && \
    cmake -S . -B build \
        -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --target ninja -- -j$(getconf _NPROCESSORS_ONLN) && \
    strip --strip-all build/ninja && \
    cp -a build/ninja /usr/local/bin/ && \
    cd .. && \
    rm -rf v${NINJA_VERSION}.tar.gz ninja-${NINJA_VERSION}

RUN export CLANG_VERSION="21.1.8" && \
    wget --no-check-certificate https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${CLANG_VERSION}.tar.gz && \
    tar -xvpf llvmorg-${CLANG_VERSION}.tar.gz && \
    cd llvm-project-llvmorg-${CLANG_VERSION} && \
    sed -i 's|\(virtual unsigned GetDefaultDwarfVersion() const { return \)5;|\14;|' clang/include/clang/Driver/ToolChain.h && \
    sed -i 's|^\(unsigned ToolChain::GetDefaultDwarfVersion() const {\)|\1\n  return 4;|' clang/lib/Driver/ToolChain.cpp && \
    cmake -S llvm -B build \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="/usr/bin/gcc-12" \
        -DCMAKE_CXX_COMPILER="/usr/bin/g++-12" \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
        -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
        -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
        -DCMAKE_INSTALL_PREFIX="/opt/clang" && \
    cmake --build build --target all && \
    cmake --install build --prefix "/opt/clang" && \
    cmake -S runtimes -B build_runtimes \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
        -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
        -DLLVM_USE_LINKER=lld \
        -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
        -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
        -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
        -DCMAKE_INSTALL_PREFIX="/opt/clang" && \
    cmake --build build_runtimes --target cxx cxxabi unwind && \
    cmake --build build_runtimes --target install-cxx install-cxxabi install-unwind && \
    cd .. && \
    rm -rf llvmorg-${CLANG_VERSION}.tar.gz llvm-project-llvmorg-${CLANG_VERSION}

RUN export XCB_PROTO_VERSION="1.17.0" && \
    export LIBXCB_VERSION="1.17.0" && \
    export XCB_UTIL_VERSION="0.4.1" && \
    export XCB_UTIL_IMAGE_VERSION="0.4.1" && \
    export XCB_UTIL_KEYSYMS_VERSION="0.4.1" && \
    export XCB_UTIL_RENDERUTIL_VERSION="0.3.10" && \
    export XCB_UTIL_WM_VERSION="0.4.2" && \
    export XCB_UTIL_CURSOR_VERSION="0.1.6" && \
    export XCB_UTIL_ERRORS_VERSION="1.0.1" && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-${XCB_PROTO_VERSION}.tar.xz && \
    tar -xvpf xcb-proto-${XCB_PROTO_VERSION}.tar.xz && \
    cd xcb-proto-${XCB_PROTO_VERSION} && \
    find src -name '*.xml' -exec sed -i 's|\xe2\x80\x98|\&apos;|g ; s|\xe2\x80\x99|\&apos;|g ; s|\xe2\x80\x9c|\&quot;|g ; s|\xe2\x80\x9d|\&quot;|g' \{\} \; && \
    ./configure --prefix=/opt/xcb PYTHON=python3 && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/libxcb-${LIBXCB_VERSION}.tar.xz && \
    tar -xvpf libxcb-${LIBXCB_VERSION}.tar.xz && \
    cd libxcb-${LIBXCB_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen --enable-ge --enable-xevie --enable-xprint --enable-selinux PKG_CONFIG_PATH=/opt/xcb/share/pkgconfig CFLAGS="-O3 -DNDEBUG" PYTHON=python3 && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-${XCB_UTIL_VERSION}.tar.xz && \
    tar -xvpf xcb-util-${XCB_UTIL_VERSION}.tar.xz && \
    cd xcb-util-${XCB_UTIL_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz && \
    tar -xvpf xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz && \
    cd xcb-util-image-${XCB_UTIL_IMAGE_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz && \
    tar -xvpf xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz && \
    cd xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz && \
    tar -xvpf xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz && \
    cd xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz && \
    tar -xvpf xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz && \
    cd xcb-util-wm-${XCB_UTIL_WM_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz && \
    tar -xvpf xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz && \
    cd xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz && \
    tar -xvpf xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz && \
    cd xcb-util-errors-${XCB_UTIL_ERRORS_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/share/pkgconfig CFLAGS="-O3 -DNDEBUG" PYTHON=python3 && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    rm -rf xcb-proto-${XCB_PROTO_VERSION}.tar.xz xcb-proto-${XCB_PROTO_VERSION} libxcb-${LIBXCB_VERSION}.tar.xz libxcb-${LIBXCB_VERSION} xcb-util-${XCB_UTIL_VERSION}.tar.xz xcb-util-${XCB_UTIL_VERSION} xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz xcb-util-image-${XCB_UTIL_IMAGE_VERSION} xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION} xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION} xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz xcb-util-wm-${XCB_UTIL_WM_VERSION} xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION} xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}

RUN export OPENSSL_VERSION="3.6.0" && \
    wget --no-check-certificate https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xvpf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure linux-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armv4| ; s|^powerpc64le$|ppc64le|') --prefix=/opt/openssl --openssldir=/etc/ssl zlib no-shared && \
    make depend && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    rm -rf openssl-${OPENSSL_VERSION}.tar.gz openssl-${OPENSSL_VERSION}

RUN ICU_VERSION="78.2" && \
    wget --no-check-certificate https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}/icu4c-${ICU_VERSION}-sources.tgz && \
    tar -xvpf icu4c-${ICU_VERSION}-sources.tgz && \
    cd icu/source && \
    CC="/opt/clang/bin/clang" \
    CXX="/opt/clang/bin/clang++" \
    CPP="/opt/clang/bin/clang++ -E" \
    LDFLAGS="-fuse-ld=lld" \
    CFLAGS="-O3 -DNDEBUG -fPIC" \
    CXXFLAGS="-O3 -DNDEBUG -fPIC" \
    CPPFLAGS="-O3 -DNDEBUG -fPIC" \
    ./configure --prefix=/opt/icu --enable-shared --disable-static --disable-tests --disable-samples --with-data-packaging=library && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd ../.. && \
    rm -rf icu icu4c-${ICU_VERSION}-sources.tgz

RUN export QT_VERSION="6.10.1" && \
    export QT_ARCHIVE_PATH="archive/qt/$(echo ${QT_VERSION} | sed 's|\([0-9]*\.[0-9]*\)\..*|\1|')/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz" && \
    wget --no-check-certificate --tries=1 "https://download.qt.io/${QT_ARCHIVE_PATH}" || \
    wget --no-check-certificate --tries=1 "https://mirror.accum.se/mirror/qt.io/qtproject/${QT_ARCHIVE_PATH}" || \
    wget --no-check-certificate --tries=1 "https://www.nic.funet.fi/pub/mirrors/download.qt-project.org/${QT_ARCHIVE_PATH}" || \
    wget --no-check-certificate --tries=1 "https://qt-mirror.dannhauer.de/${QT_ARCHIVE_PATH}" && \
    tar -xvpf qt-everywhere-src-${QT_VERSION}.tar.xz && \
    cd qt-everywhere-src-${QT_VERSION} && \
    echo 'target_link_libraries(XcbQpaPrivate PRIVATE XCB::UTIL -lXau -lXdmcp)' >> qtbase/src/plugins/platforms/xcb/CMakeLists.txt && \
    echo 'target_link_libraries(Network PRIVATE ${CMAKE_DL_LIBS})' >> qtbase/src/network/CMakeLists.txt && \
    echo 'target_link_libraries(GstreamerMediaPluginImplPrivate PRIVATE -lXau -lXdmcp)' >> qtmultimedia/src/plugins/multimedia/gstreamer/CMakeLists.txt && \
    mkdir build && \
    cd build && \
    ../configure -prefix /opt/qt6 -opensource -confirm-license \
        -no-feature-forkfd_pidfd \
        -cmake-generator Ninja -release -shared -platform linux-clang -linker lld \
        -skip qtactiveqt -skip qtdoc -skip qtwebengine -skip qtwebview \
        -nomake examples -nomake tests -nomake benchmarks -nomake manual-tests -nomake minimal-static-tests \
        -gui -widgets -dbus-linked -accessibility \
        -qt-doubleconversion -glib -icu -qt-pcre -system-zlib \
        -ssl -openssl-linked -no-libproxy -system-proxies \
        -cups -fontconfig -system-freetype -qt-harfbuzz -gtk -opengl desktop -no-opengles3 -egl -qpa xcb -xcb-xlib \
        -no-directfb -no-eglfs -no-gbm -no-kms -no-linuxfb -xcb \
        -no-libudev -evdev -no-libinput -no-mtdev -no-tslib -bundled-xcb-xinput -xkbcommon \
        -gif -ico -qt-libpng -qt-libjpeg \
        -no-sql-db2 -no-sql-ibase -no-sql-mysql -no-sql-oci -no-sql-odbc -no-sql-psql -sql-sqlite -qt-sqlite \
        -qt-tiff -qt-webp \
        -pulseaudio -gstreamer yes \
        -qt-openxr \
        -- -Wno-dev -DOpenGL_GL_PREFERENCE=LEGACY \
        -DQT_FEATURE_optimize_full=ON -DQT_FEATURE_clangcpp=OFF -DQT_FEATURE_clang=OFF -DQT_FEATURE_ffmpeg=OFF -DQT_FEATURE_brotli=OFF \
        -DCMAKE_PREFIX_PATH="/opt/openssl;/opt/xcb;/opt/icu" -DQT_FEATURE_openssl_linked=ON -DQT_FEATURE_xkbcommon_x11=ON -DTEST_xcb_syslibs=ON \
        && \
    cmake --build . --parallel && \
    cmake --install . && \
    cd ../.. && \
    rm -rf qt-everywhere-src-${QT_VERSION}.tar.xz qt-everywhere-src-${QT_VERSION}

RUN export QT6GTK2_COMMIT="38ce539b2452f0799fc6940288dbae6a4f2f0337" && \
    wget --continue --tries=20 --read-timeout=30 --no-check-certificate https://www.opencode.net/trialuser/qt6gtk2/-/archive/${QT6GTK2_COMMIT}/qt6gtk2-${QT6GTK2_COMMIT}.tar.gz && \
    tar -xvpf qt6gtk2-${QT6GTK2_COMMIT}.tar.gz && \
    cd qt6gtk2-${QT6GTK2_COMMIT} && \
    sed -i 's|\(newSize =.*"GtkSpinButton".*;\)|//\1|' src/qt6gtk2-style/qgtkstyle.cpp && \
    mkdir build && \
    cd build && \
    /opt/qt6/bin/qmake -r CONFIG+=release ../qt6gtk2.pro && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd ../.. && \
    rm -rf qt6gtk2-${QT6GTK2_COMMIT}.tar.gz qt6gtk2-${QT6GTK2_COMMIT}

RUN export QT6CT_COMMIT="00823e41aa60e8fe266d5aee328e82ad1ad94348" && \
    wget --continue --tries=20 --read-timeout=30 --no-check-certificate https://www.opencode.net/trialuser/qt6ct/-/archive/${QT6CT_COMMIT}/qt6ct-${QT6CT_COMMIT}.tar.gz && \
    tar -xvpf qt6ct-${QT6CT_COMMIT}.tar.gz && \
    cd qt6ct-${QT6CT_COMMIT} && \
    mkdir build && \
    cd build && \
    /opt/qt6/bin/qmake -r CONFIG+=release ../qt6ct.pro && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd ../.. && \
    rm -rf qt6ct-${QT6CT_COMMIT}.tar.gz qt6ct-${QT6CT_COMMIT}

RUN export ADWAITA_QT_COMMIT="0a774368916def5c9889de50f3323dec11de781e" && \
    wget --no-check-certificate https://github.com/FedoraQt/adwaita-qt/archive/${ADWAITA_QT_COMMIT}.tar.gz && \
    tar -xvpf ${ADWAITA_QT_COMMIT}.tar.gz && \
    cd adwaita-qt-${ADWAITA_QT_COMMIT} && \
    cmake -S . -B build \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=/opt/qt6 \
        -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
        -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
        -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
        -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
        -DUSE_QT6=true && \
    cmake --build build --target all && \
    cmake --install build && \
    cd .. && \
    rm -rf ${ADWAITA_QT_COMMIT}.tar.gz adwaita-qt-${ADWAITA_QT_COMMIT}

RUN export QGNOMEPLATFORM_COMMIT="d86d6baab74c3e69094083715ffef4aef2e516dd" && \
    wget --no-check-certificate https://github.com/FedoraQt/QGnomePlatform/archive/${QGNOMEPLATFORM_COMMIT}.tar.gz && \
    tar -xvpf ${QGNOMEPLATFORM_COMMIT}.tar.gz && \
    cd QGnomePlatform-${QGNOMEPLATFORM_COMMIT} && \
    sed -i 's|\(find_package(QT NAMES Qt6 COMPONENTS\)|\1 GuiPrivate WaylandClientPrivate|' CMakeLists.txt && \
    sed -i 's|\(CONFIG REQUIRED COMPONENTS\)|\1\n    GuiPrivate\n    WaylandClientPrivate|' CMakeLists.txt && \
    sed -i 's|\(waylandWindow()->\)setMouseCursor|\1applyCursor|g' src/decoration/qgnomeplatformdecoration.cpp && \
    sed -i 's|/qgenericunixthemes_p\.h>|/qgenericunixtheme_p.h>|g' src/theme/qgnomeplatformtheme.cpp && \
    cmake -S . -B build \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_PREFIX_PATH=/opt/qt6 \
        -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
        -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
        -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
        -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
        -DUSE_QT6=true && \
    cmake --build build --target all && \
    cmake --install build && \
    cd .. && \
    rm -rf ${QGNOMEPLATFORM_COMMIT}.tar.gz QGnomePlatform-${QGNOMEPLATFORM_COMMIT}

RUN export QADWAITA_DECORATIONS_COMMIT="22a97da98a8d91021c63600250711adf4ccf11d7" && \
    wget --no-check-certificate https://github.com/FedoraQt/QAdwaitaDecorations/archive/${QADWAITA_DECORATIONS_COMMIT}.tar.gz && \
    tar -xvpf ${QADWAITA_DECORATIONS_COMMIT}.tar.gz && \
    cd QAdwaitaDecorations-${QADWAITA_DECORATIONS_COMMIT} && \
    cmake -S . -B build \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=/opt/qt6 \
        -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
        -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
        -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
        -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
        -DUSE_QT6=true && \
    cmake --build build --target all && \
    cmake --install build && \
    cd .. && \
    rm -rf ${QADWAITA_DECORATIONS_COMMIT}.tar.gz QAdwaitaDecorations-${QADWAITA_DECORATIONS_COMMIT}

# @todo Build appimagetool and type2-runtime from source?
RUN export APPIMAGETOOL_VERSION="continuous" && \
    export TYPE2_RUNTIME_VERSION="continuous" && \
    export IP7ZIP_VERSION="2501" && \
    echo "|x86_64|arm|aarch64|" | grep -v "|$(gcc -dumpmachine | sed 's|-.*||')|" >/dev/null || ( \
    wget --no-check-certificate https://7-zip.org/a/7z${IP7ZIP_VERSION}-linux-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^x86_64$|x64| ; s|^aarch64$|arm64|').tar.xz -O 7z${IP7ZIP_VERSION}-linux.tar.xz && \
    mkdir -p 7z${IP7ZIP_VERSION}-linux && \
    tar -xvpf 7z${IP7ZIP_VERSION}-linux.tar.xz --directory=7z${IP7ZIP_VERSION}-linux && \
    wget --no-check-certificate https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage -O appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage && \
    mkdir squashfs-root && \
    cd squashfs-root && \
    ../7z${IP7ZIP_VERSION}-linux/7zzs x ../appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage && \
    cd .. && \
    rm -rf appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage 7z${IP7ZIP_VERSION}-linux.tar.xz 7z${IP7ZIP_VERSION}-linux && \
    mv squashfs-root /opt/appimagetool && \
    chmod -R 755 /opt/appimagetool && \
    wget --no-check-certificate https://github.com/AppImage/type2-runtime/releases/download/${TYPE2_RUNTIME_VERSION}/runtime-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|') -O /opt/runtime-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|') && \
    echo "#!/bin/sh -e\n/opt/appimagetool/AppRun --runtime-file /opt/runtime-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|') \"\${@}\"" > /usr/local/bin/appimagetool && \
    chmod 755 /opt/runtime-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|') /usr/local/bin/appimagetool )

RUN export LINUXDEPLOYQT_COMMIT="7e7a01d565dde3c5e116c9369026c27a2903bb9d" && \
    git -c http.sslVerify=false clone https://github.com/probonopd/linuxdeployqt.git linuxdeployqt && \
    cd linuxdeployqt && \
    git checkout -f ${LINUXDEPLOYQT_COMMIT} && \
    git clean -dfx && \
    cmake -S . -B build \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_PREFIX_PATH=/opt/qt6 \
        -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
        -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
        -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
        -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
        -DGIT_COMMIT=${LINUXDEPLOYQT_COMMIT} \
        -DGIT_TAG_NAME=${LINUXDEPLOYQT_COMMIT} && \
    cmake --build build --target all && \
    strip --strip-all build/tools/linuxdeployqt/linuxdeployqt && \
    cp -a build/tools/linuxdeployqt/linuxdeployqt /usr/local/bin/ && \
    cd .. && \
    rm -rf linuxdeployqt

RUN export PATCHELF_VERSION="0.18.0" && \
    wget --no-check-certificate https://github.com/NixOS/patchelf/releases/download/${PATCHELF_VERSION}/patchelf-${PATCHELF_VERSION}.tar.bz2 && \
    tar -xvpf patchelf-${PATCHELF_VERSION}.tar.bz2 && \
    cd patchelf-${PATCHELF_VERSION} && \
    CC="/opt/clang/bin/clang" \
    CXX="/opt/clang/bin/clang++" \
    CPP="/opt/clang/bin/clang++ -E" \
    LDFLAGS="-fuse-ld=lld" \
    ./configure --prefix=/usr/local && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    strip --strip-all src/patchelf && \
    cp -a src/patchelf /usr/local/bin/ && \
    cd .. && \
    rm -rf patchelf-${PATCHELF_VERSION}.tar.bz2 patchelf-${PATCHELF_VERSION}
