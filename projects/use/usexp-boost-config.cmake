set(prj boost)
# this file (-config) installed to share/cmake
get_filename_component(XP_ROOTDIR ${CMAKE_CURRENT_LIST_DIR}/../.. ABSOLUTE)
get_filename_component(XP_ROOTDIR ${XP_ROOTDIR} ABSOLUTE) # remove relative parts
string(TOUPPER ${prj} PRJ)
@USE_SCRIPT_INSERT@
if(NOT DEFINED XP_USE_LATEST_BOOST)
  option(XP_USE_LATEST_BOOST "build with boost @BOOST_NEWVER@ instead of @BOOST_OLDVER@" OFF)
endif()
if(XP_USE_LATEST_BOOST)
  set(BOOST_VER @BOOST_NEWVER@)
else()
  set(BOOST_VER @BOOST_OLDVER@)
endif()
set(BOOST_VERSION "${BOOST_VER} [@PROJECT_NAME@]")
if(NOT DEFINED Boost_LIBS)
  # dependencies determined by 'grep _DEPS boost_*/*-static.cmake'
  set(Boost_LIBS   # dependency order
    log_setup      # dep:log
    ######
    log            # dep:thread
    ######
    graph          # dep:regex
    json           # dep:container
    thread         # dep:atomic
    timer          # dep:chrono
    wserialization # dep:serialization
    ######
    atomic
    chrono
    container
    date_time
    filesystem
    iostreams
    nowide
    program_options
    random
    regex
    serialization
    system
    test_exec_monitor
    unit_test_framework
    )
endif()
list(FIND Boost_LIBS iostreams idx)
if(NOT ${idx} EQUAL -1)
  # iostreams depends on zlib bzip2
  xpFindPkg(PKGS bzip2 zlib) # dependencies
endif()
# see BoostConfig.cmake for details on the following variables
set(Boost_FIND_QUIETLY TRUE)
set(Boost_USE_STATIC_LIBS ON)
set(Boost_USE_MULTITHREADED ON)
set(Boost_USE_STATIC_RUNTIME ON)
#set(Boost_VERBOSE TRUE) # enable verbose output of BoostConfig.cmake
#set(Boost_DEBUG TRUE) # enable debug (even more verbose) output of BoostConfig.cmake
find_package(Boost ${BOOST_VER} REQUIRED COMPONENTS ${Boost_LIBS}
  PATHS ${XP_ROOTDIR}/lib/cmake/Boost-${BOOST_VER} NO_DEFAULT_PATH
  )
mark_as_advanced(Boost_DIR)
set(${PRJ}_LIBRARIES ${Boost_LIBRARIES})
set(reqVars ${PRJ}_VERSION ${PRJ}_LIBRARIES)
include(FindPackageHandleStandardArgs)
set(FPHSA_NAME_MISMATCHED TRUE) # find_package_handle_standard_args NAME_MISMATCHED (prefix usexp-)
find_package_handle_standard_args(${prj} REQUIRED_VARS ${reqVars})
mark_as_advanced(${reqVars})
