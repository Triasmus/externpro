# JXRLIB_FOUND - jxrlib was found
# JXRLIB_VER - jxrlib version
# JXRLIB_LIBRARIES - the jxrlib library
set(prj jxrlib)
# this file (-config) installed to share/cmake
get_filename_component(XP_ROOTDIR ${CMAKE_CURRENT_LIST_DIR}/../.. ABSOLUTE)
get_filename_component(XP_ROOTDIR ${XP_ROOTDIR} ABSOLUTE) # remove relative parts
string(TOUPPER ${prj} PRJ)
set(${PRJ}_VER "@VER@ [@PROJECT_NAME@]")
# targets file (-targets) installed to lib/cmake
include(${XP_ROOTDIR}/lib/cmake/${prj}_@VER@-targets.cmake)
set(${PRJ}_LIBRARIES xpro::jxrlib)
set(reqVars ${PRJ}_VER ${PRJ}_LIBRARIES)
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(${prj} REQUIRED_VARS ${reqVars})
mark_as_advanced(${reqVars})
