class VtkAT82 < Formula
  desc "Toolkit for 3D computer graphics, image processing, and visualization"
  homepage "https://www.vtk.org/"
  url "https://www.vtk.org/files/release/8.2/VTK-8.2.0.tar.gz"
  sha256 "34c3dc775261be5e45a8049155f7228b6bd668106c72a3c435d95730d17d57bb"
  license "BSD-3-Clause"
  revision 1

  bottle do
    sha256 "961f425ff924bcb05d4968fec2ab3a883b1b079b3547966753ccdd86a05ff81b" => :big_sur
    sha256 "0946ccb0948815e0dd82783e66652fb36e2fb1ca52d64c858ad1c37d6f227312" => :arm64_big_sur
    sha256 "047462441e9da29fb30fd623813f0cf8d2ac622b625decca87cca64945aca945" => :catalina
    sha256 "2e1e70ac0856b2c320db624248587810b9212b919cf7055e2a46712238e71d9a" => :mojave
    sha256 "e3e0622f90192b04810ad3e2c7638c307df23b49a39e94b8993d3ae1da60b7c4" => :high_sierra
  end

  keg_only :versioned_formula

  deprecate! date: "2020-05-14", because: :versioned_formula

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "fontconfig"
  depends_on "hdf5"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "netcdf"
  depends_on "pyqt"
  depends_on "python@3.9"
  depends_on "qt"

  # Fix compile issues on Mojave and later
  patch do
    url "https://gitlab.kitware.com/vtk/vtk/commit/ca3b5a50d945b6e65f0e764b3138cad17bd7eb8d.patch"
    sha256 "4e59d1b8b2c672ae571966f3f7ce8d0c66dd3844d6eb3727012dd98c9e897a25"
  end

  # Python 3.8 compatibility
  patch do
    url "https://gitlab.kitware.com/vtk/vtk/commit/257b9d7b18d5f3db3fe099dc18f230e23f7dfbab.patch"
    sha256 "d5eef4a022d7d18087c9267c632c79bd6ef312fc6a287aeacfc44e9d47a5ec91"
  end

  # Qt 5.15 support
  patch do
    url "https://gitlab.kitware.com/vtk/vtk/-/commit/797f28697d5ba50c1fa2bc5596af626a3c277826.patch"
    sha256 "57618e316e7c3c3ade8d64c472b0ab77ebb0584d34b79c1f8dd3637d023461ff"
  end

  def install
    # Do not record compiler path because it references the shim directory
    inreplace "Common/Core/vtkConfigure.h.in", "@CMAKE_CXX_COMPILER@", "clang++"

    pyver = Language::Python.major_minor_version "python3"
    args = std_cmake_args + %W[
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
      -DCMAKE_INSTALL_NAME_DIR:STRING=#{lib}
      -DCMAKE_INSTALL_RPATH:STRING=#{lib}
      -DModule_vtkInfovisBoost=ON
      -DModule_vtkInfovisBoostGraphAlgorithms=ON
      -DModule_vtkRenderingFreeTypeFontConfig=ON
      -DVTK_REQUIRED_OBJCXX_FLAGS=''
      -DVTK_USE_COCOA=ON
      -DVTK_USE_SYSTEM_EXPAT=ON
      -DVTK_USE_SYSTEM_HDF5=ON
      -DVTK_USE_SYSTEM_JPEG=ON
      -DVTK_USE_SYSTEM_LIBXML2=ON
      -DVTK_USE_SYSTEM_NETCDF=ON
      -DVTK_USE_SYSTEM_PNG=ON
      -DVTK_USE_SYSTEM_TIFF=ON
      -DVTK_USE_SYSTEM_ZLIB=ON
      -DVTK_WRAP_PYTHON=ON
      -DVTK_PYTHON_VERSION=3
      -DPYTHON_EXECUTABLE=#{Formula["python@3.9"].opt_bin}/python3
      -DVTK_INSTALL_PYTHON_MODULE_DIR=#{lib}/python#{pyver}/site-packages
      -DVTK_QT_VERSION:STRING=5
      -DVTK_Group_Qt=ON
      -DVTK_WRAP_PYTHON_SIP=ON
      -DSIP_PYQT_DIR='#{Formula["pyqt5"].opt_share}/sip'
    ]

    mkdir "build" do
      system "cmake", "..", *args
      system "make"
      system "make", "install"
    end

    # Avoid hard-coding HDF5's Cellar path
    inreplace Dir["#{lib}/cmake/**/vtkhdf5.cmake"].first,
              Formula["hdf5"].prefix.realpath,
              Formula["hdf5"].opt_prefix
    # get rid of bad include paths on 10.14+
    if MacOS.version >= :mojave
      inreplace Dir["#{lib}/cmake/vtk-*/Modules/vtklibxml2.cmake"], %r{;/Library/Developer/CommandLineTools[^"]*}, ""
      inreplace Dir["#{lib}/cmake/vtk-*/Modules/vtkexpat.cmake"], %r{;/Library/Developer/CommandLineTools[^"]*}, ""
      inreplace Dir["#{lib}/cmake/vtk-*/Modules/vtkzlib.cmake"], %r{;/Library/Developer/CommandLineTools[^"]*}, ""
      inreplace Dir["#{lib}/cmake/vtk-*/Modules/vtkpng.cmake"], %r{;/Library/Developer/CommandLineTools[^"]*}, ""
    end
  end

  test do
    vtk_include = Dir[opt_include/"vtk-*"].first
    major, minor = vtk_include.match(/.*-(.*)$/)[1].split(".")

    (testpath/"version.cpp").write <<~EOS
      #include <vtkVersion.h>
      #include <assert.h>
      int main(int, char *[]) {
        assert (vtkVersion::GetVTKMajorVersion()==#{major});
        assert (vtkVersion::GetVTKMinorVersion()==#{minor});
        return EXIT_SUCCESS;
      }
    EOS

    system ENV.cxx, "-std=c++11", "version.cpp", "-I#{vtk_include}"
    system "./a.out"
    system "#{bin}/vtkpython", "-c", "exit()"
  end
end
