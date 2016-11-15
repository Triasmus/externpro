########################################
# xpfunmac.cmake
#  xp = intended to be used both internally (by externpro) and externally
#  fun = functions
#  mac = macros
# functions and macros should begin with xp prefix
# functions create a local scope for variables, macros use the global scope

set(xpThisDir ${CMAKE_CURRENT_LIST_DIR})
include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)

macro(xpProOption prj)
  string(TOUPPER "${prj}" PRJ)
  option(XP_PRO_${PRJ} "include ${prj}" OFF)
  if(XP_DEFAULT)
    set_property(CACHE XP_PRO_${PRJ} PROPERTY TYPE INTERNAL)
  else()
    set_property(CACHE XP_PRO_${PRJ} PROPERTY TYPE BOOL)
  endif()
endmacro()

function(xpGetArgValue)
  set(oneValueArgs ARG VALUE)
  set(multiValueArgs VALUES)
  cmake_parse_arguments(P1 "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(P1_ARG AND P1_VALUE AND P1_UNPARSED_ARGUMENTS)
    cmake_parse_arguments(P2 "" "${P1_ARG}" "" ${P1_UNPARSED_ARGUMENTS})
    if(P2_${P1_ARG})
      set(${P1_VALUE} "${P2_${P1_ARG}}" PARENT_SCOPE)
    else()
      set(${P1_VALUE} "unknown" PARENT_SCOPE)
    endif()
  elseif(P1_ARG AND P1_VALUES AND P1_UNPARSED_ARGUMENTS)
    cmake_parse_arguments(P3 "" "" "${P1_ARG}" ${P1_UNPARSED_ARGUMENTS})
    if(P3_${P1_ARG})
      set(${P1_VALUES} "${P3_${P1_ARG}}" PARENT_SCOPE)
    else()
      set(${P1_VALUES} "unknown" PARENT_SCOPE)
    endif()
  else()
    message(AUTHOR_WARNING "incorrect usage of xpGetArgValue")
  endif()
endfunction()

function(xpCloneRepo)
  set(oneValueArgs NAME GIT_ORIGIN GIT_UPSTREAM GIT_TRACKING_BRANCH GIT_TAG GIT_REF PATCH)
  cmake_parse_arguments(P "" "${oneValueArgs}" "" ${ARGN})
  string(TOLOWER ${P_NAME} prj)
  if(DEFINED P_GIT_ORIGIN AND NOT TARGET ${prj}_repo)
    if(DEFINED P_PATCH AND DEFINED P_GIT_REF)
      set(patchCmd ${GIT_EXECUTABLE} diff --ignore-submodules ${P_GIT_REF} -- > ${P_PATCH})
    else()
      set(patchCmd ${CMAKE_COMMAND} -E echo "no patch for ${prj}")
    endif()
    if(DEFINED P_GIT_UPSTREAM)
      if(DEFINED P_GIT_TRACKING_BRANCH)
        set(trackingBranch ${P_GIT_TRACKING_BRANCH})
      else()
        set(trackingBranch master)
      endif()
      if(GIT_VERSION_STRING VERSION_LESS 1.8)
        set(upstreamCmd --set-upstream ${trackingBranch} upstream/${trackingBranch})
      else()
        set(upstreamCmd --set-upstream-to=upstream/${trackingBranch} ${trackingBranch})
      endif()
      ExternalProject_Add(${prj}_repo
        GIT_REPOSITORY ${P_GIT_ORIGIN} GIT_TAG ${P_GIT_TAG}
        #DOWNLOAD_COMMAND # tricky: must not be defined for git clone to happen
        PATCH_COMMAND ${GIT_EXECUTABLE} remote add upstream ${P_GIT_UPSTREAM}
        UPDATE_COMMAND ${GIT_EXECUTABLE} fetch --all
        CONFIGURE_COMMAND ${GIT_EXECUTABLE} branch ${upstreamCmd}
        BUILD_COMMAND ${patchCmd}
        INSTALL_COMMAND ""
        BUILD_IN_SOURCE 1 # <BINARY_DIR>==<SOURCE_DIR>
        DOWNLOAD_DIR ${NULL_DIR} INSTALL_DIR ${NULL_DIR}
        )
    else()
      ExternalProject_Add(${prj}_repo
        GIT_REPOSITORY ${P_GIT_ORIGIN} GIT_TAG ${P_GIT_TAG}
        #DOWNLOAD_COMMAND # tricky: must not be defined for git clone to happen
        PATCH_COMMAND ""
        UPDATE_COMMAND ${GIT_EXECUTABLE} fetch --all
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ${patchCmd}
        INSTALL_COMMAND ""
        BUILD_IN_SOURCE 1 # <BINARY_DIR>==<SOURCE_DIR>
        DOWNLOAD_DIR ${NULL_DIR} INSTALL_DIR ${NULL_DIR}
        )
    endif()
  endif()
endfunction()

function(xpCloneProject)
  set(oneValueArgs NAME SUPERPRO)
  set(multiValueArgs SUBPRO)
  cmake_parse_arguments(R "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(DEFINED R_SUPERPRO)
    return() # we'll clone subprojects as part of their superproject
  endif()
  string(TOUPPER ${R_NAME} PRJ)
  if(XP_DEFAULT OR XP_PRO_${PRJ})
    xpCloneRepo(${ARGN})
    foreach(sub ${R_SUBPRO})
      string(TOUPPER ${sub} SUB)
      xpCloneRepo(${PRO_${SUB}})
    endforeach()
  endif()
endfunction()

function(xpDownload pkg_url pkg_md5 download_path)
  if(IS_DIRECTORY ${download_path})
    get_filename_component(fn ${pkg_url} NAME)
    set(pkg_path ${download_path}/${fn})
  else()
    get_filename_component(fn ${download_path} NAME)
    set(pkg_path ${download_path})
  endif()
  add_custom_target(download_${fn} ALL)
  add_custom_command(TARGET download_${fn}
    COMMAND ${CMAKE_COMMAND} -Dpkg_url:STRING="${pkg_url}" -Dpkg_md5:STRING=${pkg_md5}
      -Dpkg_dir:STRING=${pkg_path}
      -P ${MODULES_DIR}/cmsdownload.cmake
    COMMENT "Downloading ${fn}..."
    )
  set_property(TARGET download_${fn} PROPERTY FOLDER ${dwnld_folder})
endfunction()

function(xpNewDownload)
  set(oneValueArgs DLURL DLMD5 DLNAME)
  cmake_parse_arguments(P "" "${oneValueArgs}" "" ${ARGN})
  if(DEFINED P_DLNAME)
    set(fn ${P_DLNAME})
  else()
    get_filename_component(fn ${P_DLURL} NAME)
  endif()
  set(pkgPath ${DWNLD_DIR}/${fn})
  if(NOT TARGET download_${fn})
    add_custom_target(download_${fn} ALL)
    add_custom_command(TARGET download_${fn}
      COMMAND ${CMAKE_COMMAND} -Dpkg_url:STRING="${P_DLURL}" -Dpkg_md5:STRING=${P_DLMD5}
        -Dpkg_dir:STRING=${pkgPath}
        -P ${MODULES_DIR}/cmsdownload.cmake
      COMMENT "Downloading ${fn}..."
      )
    set_property(TARGET download_${fn} PROPERTY FOLDER ${dwnld_folder})
  endif()
endfunction()

function(xpDownloadProject)
  set(oneValueArgs DLURL DLMD5)
  cmake_parse_arguments(R "" "${oneValueArgs}" "" ${ARGN})
  if(DEFINED R_DLURL AND DEFINED R_DLMD5)
    xpNewDownload(${ARGN})
  endif()
endfunction()

function(xpPatch)
  set(options NPM_INSTALL)
  set(oneValueArgs NAME PARENT SUBDIR PATCH PATCH_STRIP DLURL DLMD5 DLNAME)
  set(multiValueArgs NPM_FLAGS)
  cmake_parse_arguments(P "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  string(TOLOWER ${P_NAME} prj)
  if(DEFINED P_PARENT)
    set(tgt ${P_PARENT}_${prj})
  else()
    set(tgt ${prj})
  endif()
  if(TARGET ${tgt})
    return()
  endif()
  # unless there's a package to extract or a patch to apply,
  # there's no reason to create a target with ExternalProject_Add()
  if(NOT DEFINED P_DLURL AND NOT DEFINED P_PATCH)
    return()
  endif()
  if(P_NPM_INSTALL)
    # npm installs into the download directory (DWNLD_DIR)
    # use for libraries that can be pulled directly through npm without
    # the need for a patch
    if(NOT DEFINED NODE_EXE OR NOT DEFINED NODE_NPM)
      message(FATAL_ERROR "${P_NAME} with NPM_INSTALL doesn't have NODE_EXE or NODE_NPM defined")
    endif()
    list(APPEND P_NPM_FLAGS --no-bin-links --only=prod --legacy-bundling)
    set(patchCmd ${NODE_EXE} ${NODE_NPM} install ${P_NPM_FLAGS})
  elseif(DEFINED P_PATCH)
    if(COMMAND patch_patch)
      if(NOT TARGET patch)
        patch_patch()
      endif()
      set(depsOpt DEPENDS)
      list(APPEND depsList patch)
    else()
      xpGetPkgVar(patch CMD)
    endif()
    if(DEFINED P_PATCH_STRIP)
      set(patchCmd ${PATCH_CMD} -p${P_PATCH_STRIP} < ${P_PATCH})
    else()
      set(patchCmd ${PATCH_CMD} -p1 < ${P_PATCH})
    endif()
  else()
    set(patchCmd ${CMAKE_COMMAND} -E echo "no patch for ${prj}")
  endif()
  if(DEFINED P_PARENT)
    set(depsOpt DEPENDS)
    list(APPEND depsList ${P_PARENT})
    set(srcDirOpt SOURCE_DIR)
    ExternalProject_Get_Property(${P_PARENT} SOURCE_DIR)
    if(DEFINED P_SUBDIR)
      set(srcDir ${SOURCE_DIR}/${P_SUBDIR})
    else()
      set(srcDir ${SOURCE_DIR}/${prj})
    endif()
  endif()
  if(DEFINED P_DLNAME)
    set(dlnOpt DOWNLOAD_NAME)
  endif()
  if(DEFINED P_DLURL AND DEFINED P_DLMD5)
    set(urlOpt URL)
    set(md5Opt URL_MD5)
  elseif(NOT DEFINED P_DLURL AND NOT DEFINED P_DLMD5)
    set(urlOpt DOWNLOAD_COMMAND)
    set(md5Opt ${CMAKE_COMMAND} -E echo "no download for ${prj}")
  endif()
  ExternalProject_Add(${tgt} ${depsOpt} ${depsList}
    ${urlOpt} ${P_DLURL} ${md5Opt} ${P_DLMD5}
    DOWNLOAD_DIR ${DWNLD_DIR} ${dlnOpt} ${P_DLNAME}
    ${srcDirOpt} ${srcDir}
    PATCH_COMMAND ${patchCmd}
    UPDATE_COMMAND "" CONFIGURE_COMMAND "" BUILD_COMMAND "" INSTALL_COMMAND ""
    BINARY_DIR ${NULL_DIR} INSTALL_DIR ${NULL_DIR}
    )
  if(UNIX AND P_NPM_INSTALL) # ensure permissions are proper on unix
    ExternalProject_Get_Property(${tgt} SOURCE_DIR)
    ExternalProject_Add_Step(${tgt} ${tgt}_permissions
      COMMAND chmod -R u+rwX,go+rX,go-w ${SOURCE_DIR} # 755 for directories 644 for files
      DEPENDEES download # change permissions after files are downloaded
      DEPENDERS patch # change permissions before npm install
      )
  endif()
  set_property(TARGET ${tgt} PROPERTY FOLDER ${src_folder})
endfunction()

function(xpPatchProject)
  set(oneValueArgs NAME SUPERPRO)
  set(multiValueArgs SUBPRO)
  cmake_parse_arguments(R "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(DEFINED R_SUPERPRO)
    return() # we'll patch subprojects as part of their superproject
  endif()
  string(TOUPPER ${R_NAME} PRJ)
  if(XP_DEFAULT OR XP_PRO_${PRJ})
    xpPatch(${ARGN})
    foreach(sub ${R_SUBPRO})
      string(TOUPPER ${sub} SUB)
      string(TOLOWER ${R_NAME} super)
      xpPatch(${PRO_${SUB}} PARENT ${super})
    endforeach()
  endif()
endfunction()

macro(xpBuildOnlyRelease)
  list(FIND BUILD_CONFIGS Release idx1)
  if(NOT ${idx1} EQUAL -1)
    set(BUILD_CONFIGS Release)
  else()
    message(FATAL_ERROR "a release build configuration is required")
  endif()
endmacro()

function(xpCmakeBuild XP_DEPENDS)
  cmake_parse_arguments(P NO_INSTALL "TGT;BUILD_TARGET" "" ${ARGN})
  if(ARGV1) # ADDITIONAL_DEPENDS...
    foreach(dep ${ARGV1})
      list(APPEND ADDITIONAL_DEPENDS ${dep})
    endforeach()
  endif()
  if(ARGV2) # XP_CONFIGURE...
    foreach(def ${ARGV2})
      list(APPEND XP_CONFIGURE_APPEND ${def})
    endforeach()
  endif()
  if(WIN32)
    set(XP_CONFIGURE_GEN ${CMAKE_GENERATOR})
    set(XP_CONFIGURE_CMD
      -DCMAKE_MODULE_PATH:PATH=${MODULES_DIR}
      -DCMAKE_INSTALL_PREFIX:PATH=${STAGE_DIR}
      )
    # BUILD and INSTALL commands broken into additional steps
    # (see foreach in xpAddProject below)
    set(XP_BUILD_CMD ${CMAKE_COMMAND} -E echo "Build MSVC...")
    set(XP_INSTALL_CMD ${CMAKE_COMMAND} -E echo "Install MSVC...")
    if(DEFINED P_TGT)
      set(XP_BUILD_TGT ${XP_DEPENDS}${P_TGT}_msvc)
    else()
      set(XP_BUILD_TGT ${XP_DEPENDS}_msvc)
    endif()
    xpAddProject(${XP_BUILD_TGT})
    list(APPEND ADDITIONAL_DEPENDS ${XP_BUILD_TGT}) # serialize the build
  else()
    set(XP_CONFIGURE_GEN "")
    if(DEFINED P_BUILD_TARGET)
      set(XP_BUILD_CMD ${CMAKE_COMMAND} --build <BINARY_DIR> --target ${P_BUILD_TARGET})
    else()
      set(XP_BUILD_CMD) # use default
    endif()
    if(P_NO_INSTALL)
      set(XP_INSTALL_CMD ${CMAKE_COMMAND} -E echo "No install")
    elseif(DEFINED P_BUILD_TARGET)
      set(XP_INSTALL_CMD ${XP_BUILD_CMD} --target install)
    else()
      set(XP_INSTALL_CMD) # use default
    endif()
    foreach(cfg ${BUILD_CONFIGS})
      set(XP_CONFIGURE_CMD
        -DCMAKE_MODULE_PATH:PATH=${MODULES_DIR}
        -DCMAKE_INSTALL_PREFIX:PATH=${STAGE_DIR}
        -DCMAKE_BUILD_TYPE:STRING=${cfg}
        )
      if(DEFINED P_TGT)
        set(XP_BUILD_TGT ${XP_DEPENDS}${P_TGT}_${cfg})
      else()
        set(XP_BUILD_TGT ${XP_DEPENDS}_${cfg})
      endif()
      xpAddProject(${XP_BUILD_TGT})
      list(APPEND ADDITIONAL_DEPENDS ${XP_BUILD_TGT}) # serialize the build
    endforeach()
  endif()
  if(ARGV3)
    if(ARGV1)
      list(REMOVE_ITEM ADDITIONAL_DEPENDS ${ARGV1})
    endif()
    set(${ARGV3} "${ADDITIONAL_DEPENDS}" PARENT_SCOPE)
  endif()
endfunction()

function(xpAddProject XP_TARGET)
  if(NOT TARGET ${XP_TARGET})
    set(XP_DEPS ${XP_DEPENDS})
    if(DEFINED XP_CONFIGURE_APPEND)
      list(APPEND XP_CONFIGURE_CMD ${XP_CONFIGURE_APPEND})
    endif()
    if(XP_BUILD_VERBOSE)
      message(STATUS "target ${XP_TARGET}")
      xpVerboseListing("[CONFIGURE]" "${XP_CONFIGURE_CMD}")
      if(NOT "${XP_CONFIGURE_GEN}" STREQUAL "")
        xpVerboseListing("[GEN]" "${XP_CONFIGURE_GEN}")
      endif()
      if(NOT "${ADDITIONAL_DEPENDS}" STREQUAL "")
        xpVerboseListing("[DEPS]" "${ADDITIONAL_DEPENDS}")
      endif()
    else()
      message(STATUS "target ${XP_TARGET}")
    endif()
    ExternalProject_Get_Property(${XP_DEPS} SOURCE_DIR)
    ExternalProject_Add(${XP_TARGET} DEPENDS ${XP_DEPS} ${ADDITIONAL_DEPENDS}
      DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR}
      SOURCE_DIR ${SOURCE_DIR}
      CMAKE_GENERATOR ${XP_CONFIGURE_GEN} CMAKE_ARGS ${XP_CONFIGURE_CMD}
      BUILD_COMMAND ${XP_BUILD_CMD}
      INSTALL_COMMAND ${XP_INSTALL_CMD} INSTALL_DIR ${NULL_DIR}
      )
    set_property(TARGET ${XP_TARGET} PROPERTY FOLDER ${bld_folder})
    if(WIN32)
      ExternalProject_Add_Step(${XP_TARGET} bugworkaround
        # work around a cmake bug: run cmake again for changes to
        # CMAKE_CONFIGURATION_TYPES to take effect (see modules/flags.cmake)
        COMMAND ${CMAKE_COMMAND} <BINARY_DIR>
        DEPENDEES configure DEPENDERS build
        )
      if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(pfstr x64)
      elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
        set(pfstr Win32)
      endif()
      foreach(cfg ${BUILD_CONFIGS})
        # Run cmake --build with no options for quick help
        if(DEFINED P_BUILD_TARGET)
          set(build_cmd ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${cfg} --target ${P_BUILD_TARGET})
        else()
          set(build_cmd ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${cfg})
        endif()
        if(P_NO_INSTALL)
          set(install_cmd ${CMAKE_COMMAND} -E echo "No install")
        else()
          set(install_cmd ${build_cmd} --target install)
        endif()
        if(NOT MSVC10 OR ${CMAKE_MAJOR_VERSION} GREATER 2)
          # needed for cmake builds which use include_external_msproject
          list(APPEND build_cmd -- /property:Platform=${pfstr})
          list(APPEND install_cmd -- /property:Platform=${pfstr})
        endif()
        ExternalProject_Add_Step(${XP_TARGET} build_${cfg}_${pfstr}
          COMMAND ${build_cmd} DEPENDEES build DEPENDERS install
          )
        ExternalProject_Add_Step(${XP_TARGET} install_${cfg}_${pfstr}
          COMMAND ${install_cmd} DEPENDEES install
          )
        if(XP_BUILD_VERBOSE)
          string(REPLACE ";" " " build_cmd "${build_cmd}")
          string(REPLACE ";" " " install_cmd "${install_cmd}")
          message(STATUS "  [BUILD]")
          message(STATUS "  ${build_cmd}")
          message(STATUS "  [INSTALL]")
          message(STATUS "  ${install_cmd}")
        endif()
      endforeach()
    endif(WIN32)
  endif()
endfunction()

function(xpCmakePackage XP_TGTS)
  find_program(XP_FIND_RPMBUILD rpmbuild)
  mark_as_advanced(XP_FIND_RPMBUILD)
  if(XP_FIND_RPMBUILD)
    list(APPEND cpackGen RPM)
  endif()
  #####
  find_program(XP_FIND_DPKGDEB dpkg-deb)
  mark_as_advanced(XP_FIND_DPKGDEB)
  if(XP_FIND_DPKGDEB)
    list(APPEND cpackGen DEB)
  endif()
  #####
  if(${CMAKE_SYSTEM_NAME} STREQUAL SunOS)
    list(APPEND cpackGen PKG)
  endif()
  #####
  get_filename_component(cmakePath ${CMAKE_COMMAND} PATH)
  find_program(XP_CPACK_CMD cpack ${cmakePath})
  mark_as_advanced(XP_CPACK_CMD)
  if(NOT XP_CPACK_CMD)
    message(SEND_ERROR "xpCmakePackage: cpack not found")
  endif()
  #####
  foreach(tgt ${XP_TGTS})
    ExternalProject_Get_Property(${tgt} SOURCE_DIR)
    ExternalProject_Get_Property(${tgt} BINARY_DIR)
    foreach(gen ${cpackGen})
      if(NOT TARGET ${tgt}${gen})
        if(${gen} STREQUAL PKG)
          ExternalProject_Add(${tgt}${gen} DEPENDS ${tgt} ${pkgTgts}
            DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR}
            SOURCE_DIR ${SOURCE_DIR} BINARY_DIR ${BINARY_DIR}
            BUILD_COMMAND ${CMAKE_COMMAND} --build ${BINARY_DIR} --target pkg
            INSTALL_COMMAND "" INSTALL_DIR ${NULL_DIR}
            )
        else()
          ExternalProject_Add(${tgt}${gen} DEPENDS ${tgt} ${pkgTgts}
            DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR}
            SOURCE_DIR ${SOURCE_DIR} BINARY_DIR ${BINARY_DIR}
            BUILD_COMMAND ${XP_CPACK_CMD} -G ${gen} -D CPACK_OUTPUT_FILE_PREFIX=${STAGE_DIR}/pkg
            INSTALL_COMMAND "" INSTALL_DIR ${NULL_DIR}
            )
        endif()
        set_property(TARGET ${tgt}${gen} PROPERTY FOLDER ${bld_folder})
        message(STATUS "target ${tgt}${gen}")
      endif() # NOT TARGET
      list(APPEND pkgTgts ${tgt}${gen})
    endforeach() # gen
  endforeach() # tgt
  if(ARGV1)
    set(${ARGV1} "${pkgTgts}" PARENT_SCOPE)
  endif()
endfunction()

# npm installs downloaded repo to the download directory
# use for libraries that are manually downloaded from the git repo and possibly
# patched that still require an npm install (usually needed if there are
# node_module dependencies)
function(xpBuildNpmModule)
  set(oneValueArgs NAME)
  set(multiValueArgs NPM_FLAGS)
  cmake_parse_arguments(P "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  string(TOLOWER ${P_NAME} prj)
  string(TOUPPER ${P_NAME} PRJ)
  if(TARGET ${prj}_bld)
    return()
  endif()
  if(XP_DEFAULT OR XP_PRO_${PRJ})
    list(APPEND P_NPM_FLAGS --no-bin-links --only=prod --legacy-bundling)
    ExternalProject_Get_Property(${prj} SOURCE_DIR)
    ExternalProject_Add(${prj}_bld DEPENDS ${prj}
      DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR}
      SOURCE_DIR ${SOURCE_DIR}
      PATCH_COMMAND ${NODE_EXE} ${NODE_NPM} install ${P_NPM_FLAGS}
      UPDATE_COMMAND "" CONFIGURE_COMMAND "" BUILD_COMMAND "" INSTALL_COMMAND ""
      BINARY_DIR ${NULL_DIR}
      INSTALL_DIR ${NULL_DIR}
      )
    set_property(TARGET ${prj}_bld PROPERTY FOLDER ${bld_folder})
  endif()
endfunction()

function(xpMarkdownLink var _ret)
  list(LENGTH var len)
  if(NOT ${len} EQUAL 3)
    message(AUTHOR_WARNING "incorrect usage of xpMarkdownLink: ${var}")
  endif()
  list(GET var 0 text)
  list(GET var 1 url)
  list(GET var 2 title)
  set(${_ret} "[${text}](${url} '${title}')" PARENT_SCOPE)
endfunction()

set(g_README ${CMAKE_BINARY_DIR}/README.md)
set(g_READMEsub ${CMAKE_BINARY_DIR}/README.sub.md)

function(xpMarkdownReadmeInit)
  file(WRITE ${g_README} "# projects\n\n")
  file(APPEND ${g_README} "|project|license|description|version|repository|patch/diff|\n")
  file(APPEND ${g_README} "|-------|-------|-----------|-------|----------|----------|\n")
  if(EXISTS ${g_READMEsub})
    file(REMOVE ${g_READMEsub})
  endif()
endfunction()

function(xpMarkdownReadmeAppend proj)
  string(TOUPPER "${proj}" PROJ)
  if(DEFINED PRO_${PROJ})
    xpMarkdownPro(${PRO_${PROJ}})
  endif()
endfunction()

function(xpMarkdownPro)
  set(oneValueArgs NAME DESC VER GIT_REF GIT_TAG SUPERPRO DIFF)
  set(multiValueArgs WEB LICENSE REPO)
  cmake_parse_arguments(P "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  if(DEFINED P_WEB)
    xpMarkdownLink("${P_WEB}" web)
  else()
    set(web ${proj})
  endif()
  if(DEFINED P_LICENSE)
    xpMarkdownLink("${P_LICENSE}" lic)
  else()
    set(lic "unknown")
  endif()
  if(DEFINED P_DESC)
    set(desc ${P_DESC})
  else()
    set(desc "project needs description")
  endif()
  if(DEFINED P_VER)
    set(ver ${P_VER})
  else()
    set(ver "unknown")
  endif()
  if(DEFINED P_REPO)
    xpMarkdownLink("${P_REPO}" repo)
  else()
    set(repo "none")
  endif()
  if(DEFINED P_DIFF AND DEFINED P_GIT_REF AND DEFINED P_GIT_TAG)
    string(FIND ${P_GIT_REF} "/" slash) # strip off "origin/" from REF
    if(NOT ${slash} EQUAL -1)
      math(EXPR loc "${slash} + 1")
      string(SUBSTRING ${P_GIT_REF} ${loc} -1 P_GIT_REF)
    endif()
    set(diff "[diff](${P_DIFF}${P_GIT_REF}...${P_GIT_TAG} 'patch/diff')")
  else()
    set(diff "none")
  endif()
  if(DEFINED P_SUPERPRO)
    if(NOT EXISTS ${g_READMEsub})
      file(WRITE ${g_READMEsub} "\n\n## subprojects\n\n")
      file(APPEND ${g_READMEsub} "|project|sub|description|version|repository|patch/diff|\n")
      file(APPEND ${g_READMEsub} "|-------|---|-----------|-------|----------|----------|\n")
    endif()
    file(APPEND ${g_READMEsub} "|${P_SUPERPRO}|${web}|${desc}|${ver}|${repo}|${diff}|\n")
  else()
    file(APPEND ${g_README} "|${web}|${lic}|${desc}|${ver}|${repo}|${diff}|\n")
  endif()
endfunction()

function(xpMarkdownReadmeFinalize)
  if(EXISTS ${g_READMEsub})
    file(READ ${g_READMEsub} sub)
    file(APPEND ${g_README} ${sub})
  endif()
  configure_file(${g_README} ${PRO_DIR}/README.md NEWLINE_STYLE LF)
endfunction()

function(xpGetCompilerPrefix _ret)
  if(MSVC)
    if(MSVC14)
      set(prefix vc140)
    elseif(MSVC12)
      set(prefix vc120)
    elseif(MSVC11)
      set(prefix vc110)
    elseif(MSVC10)
      set(prefix vc100)
    elseif(MSVC90)
      set(prefix vc90)
    elseif(MSVC80)
      set(prefix vc80)
    elseif(MSVC71)
      set(prefix vc71)
    elseif(MSVC70)
      set(prefix vc70)
    elseif(MSVC60)
      set(prefix vc60)
    else()
      message(SEND_ERROR "xpfunmac.cmake: MSVC compiler support lacking")
    endif()
  elseif(CMAKE_COMPILER_IS_GNUCXX)
    exec_program(${CMAKE_CXX_COMPILER}
      ARGS ${CMAKE_CXX_COMPILER_ARG1} -dumpversion
      OUTPUT_VARIABLE GCC_VERSION
      )
    string(REGEX REPLACE "([0-9]+)\\.([0-9]+)\\.([0-9]+)?" "\\1\\2\\3"
      GCC_VERSION ${GCC_VERSION}
      )
    set(prefix gcc${GCC_VERSION})
  elseif(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang") # LLVM/Apple Clang (clang.llvm.org)
    if(${CMAKE_SYSTEM_NAME} STREQUAL Darwin)
      exec_program(${CMAKE_CXX_COMPILER}
        ARGS ${CMAKE_CXX_COMPILER_ARG1} -dumpversion
        OUTPUT_VARIABLE CLANG_VERSION
        )
      string(REGEX REPLACE "([0-9]+)\\.([0-9]+)(\\.[0-9]+)?"
        "clang-darwin\\1\\2" # match boost naming
        prefix ${CLANG_VERSION}
        )
    else()
      string(REGEX REPLACE "([0-9]+)\\.([0-9]+)(\\.[0-9]+)?"
        "clang\\1\\2" # match boost naming
        prefix ${CMAKE_CXX_COMPILER_VERSION}
        )
    endif()
  else()
    message(SEND_ERROR "xpfunmac.cmake: compiler support lacking: ${CMAKE_CXX_COMPILER_ID}")
  endif()
  set(${_ret} ${prefix} PARENT_SCOPE)
endfunction()

function(xpListPrependToAll var prefix)
  set(listVar)
  foreach(f ${ARGN})
    list(APPEND listVar "${prefix}/${f}")
  endforeach()
  set(${var} "${listVar}" PARENT_SCOPE)
endfunction()

function(xpListAppendTrailingSlash var)
  set(listVar)
  foreach(f ${ARGN})
    if(IS_DIRECTORY ${f})
      list(APPEND listVar "${f}/")
    else()
      list(APPEND listVar "${f}")
    endif()
  endforeach()
  set(${var} "${listVar}" PARENT_SCOPE)
endfunction()

function(xpListRemoveFromAll var match replace)
  set(listVar)
  foreach(f ${ARGN})
    string(REPLACE "${match}" "${replace}" f ${f})
    list(APPEND listVar ${f})
  endforeach()
  set(${var} "${listVar}" PARENT_SCOPE)
endfunction()

function(xpListAppendIfDne appendTo items)
  foreach(item ${items})
    list(FIND ${appendTo} ${item} index)
    if(index EQUAL -1)
      list(APPEND ${appendTo} ${item})
    endif()
  endforeach()
  set(${appendTo} ${${appendTo}} PARENT_SCOPE)
endfunction()

function(xpListRemoveIfExists removeFrom items)
  foreach(item ${items})
    list(FIND ${removeFrom} ${item} index)
    if(NOT index EQUAL -1)
      list(REMOVE_AT ${removeFrom} ${index})
    endif()
  endforeach()
  set(${removeFrom} ${${removeFrom}} PARENT_SCOPE)
endfunction()

function(xpStringTrim str)
  if("${${str}}" STREQUAL "")
    return()
  endif()
  # remove leading and trailing spaces with STRIP
  string(STRIP ${${str}} stripped)
  set(${str} ${stripped} PARENT_SCOPE)
endfunction()

function(xpStringAppend appendTo str)
  if("${${appendTo}}" STREQUAL "")
    set(${appendTo} ${str} PARENT_SCOPE)
  else()
    set(${appendTo} "${${appendTo}} ${str}" PARENT_SCOPE)
  endif()
endfunction()

function(xpStringAppendIfDne appendTo str)
  if("${${appendTo}}" STREQUAL "")
    set(${appendTo} ${str} PARENT_SCOPE)
  else()
    string(FIND ${${appendTo}} ${str} pos)
    if(${pos} EQUAL -1)
      set(${appendTo} "${${appendTo}} ${str}" PARENT_SCOPE)
    endif()
  endif()
endfunction()

function(xpStringRemoveIfExists removeFrom str)
  if("${${removeFrom}}" STREQUAL "")
    return()
  endif()
  string(FIND ${${removeFrom}} ${str} pos)
  if(${pos} EQUAL -1)
    return()
  endif()
  string(REPLACE " ${str}" "" res ${${removeFrom}})
  string(REPLACE "${str} " "" res ${${removeFrom}})
  string(REPLACE ${str} "" res ${${removeFrom}})
  xpStringTrim(res)
  set(${removeFrom} ${res} PARENT_SCOPE)
endfunction()

function(xpGetConfigureFlags cpprefix _ret)
  include(${MODULES_DIR}/flags.cmake) # populates CMAKE_*_FLAGS
  if(XP_BUILD_VERBOSE AND XP_FLAGS_VERBOSE)
    message(STATUS "  CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")
    message(STATUS "  CMAKE_C_FLAGS: ${CMAKE_C_FLAGS}")
    message(STATUS "  CMAKE_EXE_LINKER_FLAGS: ${CMAKE_EXE_LINKER_FLAGS}")
  endif()
  if(${ARGC} EQUAL 3 AND ARGV2)
    foreach(it ${ARGV2})
      xpStringRemoveIfExists(CMAKE_CXX_FLAGS "${it}")
      xpStringRemoveIfExists(CMAKE_C_FLAGS "${it}")
      xpStringRemoveIfExists(CMAKE_EXE_LINKER_FLAGS "${it}")
    endforeach()
  endif()
  set(CFG_FLAGS)
  if(NOT "${CMAKE_CXX_FLAGS}" STREQUAL "" AND NOT ${cpprefix} STREQUAL "NONE")
    list(APPEND CFG_FLAGS "${cpprefix}FLAGS=${CMAKE_CXX_FLAGS}")
    if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
      list(APPEND CFG_FLAGS "OBJCXXFLAGS=${CMAKE_CXX_FLAGS}")
    endif()
  endif()
  if(NOT "${CMAKE_C_FLAGS}" STREQUAL "")
    list(APPEND CFG_FLAGS "CFLAGS=${CMAKE_C_FLAGS}")
    if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
      list(APPEND CFG_FLAGS "OBJCFLAGS=${CMAKE_C_FLAGS}")
    endif()
  endif()
  if(NOT "${CMAKE_EXE_LINKER_FLAGS}" STREQUAL "" AND NOT "${CMAKE_EXE_LINKER_FLAGS}" STREQUAL " ")
    list(APPEND CFG_FLAGS "LDFLAGS=${CMAKE_EXE_LINKER_FLAGS}")
  endif()
  set(${_ret} ${CFG_FLAGS} PARENT_SCOPE)
endfunction()

macro(xpParentListAppend parentList items)
  list(APPEND ${parentList} ${items})
  set(${parentList} ${${parentList}} PARENT_SCOPE)
endmacro()

function(xpGitIgnoredDirs var dir)
  if(NOT GIT_FOUND)
    include(FindGit)
    find_package(Git)
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} ls-files --exclude-standard --ignored --others --directory
    WORKING_DIRECTORY ${dir}
    ERROR_QUIET
    OUTPUT_VARIABLE ignoredDirs
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  separate_arguments(ignoredDirs UNIX_COMMAND "${ignoredDirs}")
  list(APPEND ignoredDirs ${ARGN})
  xpListPrependToAll(ignoredDirs ${dir} ${ignoredDirs})
  set(${var} "${ignoredDirs}" PARENT_SCOPE)
endfunction()

function(xpGitUntrackedFiles var dir)
  if(NOT GIT_FOUND)
    include(FindGit)
    find_package(Git)
  endif()
  execute_process(
    COMMAND ${GIT_EXECUTABLE} ls-files --exclude-standard --others
    WORKING_DIRECTORY ${dir}
    ERROR_QUIET
    OUTPUT_VARIABLE untrackedFiles
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  separate_arguments(untrackedFiles UNIX_COMMAND "${untrackedFiles}")
  xpListPrependToAll(untrackedFiles ${dir} ${untrackedFiles})
  set(${var} "${untrackedFiles}" PARENT_SCOPE)
endfunction()

function(xpGlobFiles var item)
  if(IS_DIRECTORY ${item})
    string(REGEX REPLACE "/$" "" item ${item}) # remove trailing slash
    xpListPrependToAll(globexpr ${item} ${ARGN})
    # NOTE: By default GLOB_RECURSE omits directories from result list
    file(GLOB_RECURSE dirFiles ${globexpr})
    xpGitUntrackedFiles(untrackedFiles ${item})
    if(dirFiles AND untrackedFiles)
      list(REMOVE_ITEM dirFiles ${untrackedFiles})
    endif()
    list(APPEND listVar ${dirFiles})
  else()
    get_filename_component(dir ${item} DIRECTORY)
    xpListPrependToAll(globexpr ${dir} ${ARGN})
    file(GLOB match ${globexpr})
    list(FIND match ${item} idx)
    if(NOT ${idx} EQUAL -1)
      list(APPEND listVar ${item})
    endif()
  endif()
  set(${var} ${${var}} ${listVar} PARENT_SCOPE)
endfunction()

function(xpParseDir dir group)
  file(GLOB items LIST_DIRECTORIES true RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${dir}/*)
  list(SORT items)
  set(files)
  if(group)
    set(group "${group}\\\\")
  endif()
  foreach(item ${items})
    if(IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${item})
      get_filename_component(dirName ${item} NAME)
      xpParseDir(${item} "${group}${dirName}")
    else()
      list(APPEND files ${item})
    endif()
  endforeach()
  if(files)
    source_group("${group}" FILES ${files})
    list(APPEND ${projectName}_srcs ${files})
  endif()
  set(${projectName}_srcs ${${projectName}_srcs} PARENT_SCOPE)
endfunction()

function(xpAddSubdirectoryProject dir)
  cmake_parse_arguments(P "" "PROJECT_NAME" "" ${ARGN})
  if(DEFINED P_PROJECT_NAME)
    set(projectName ${P_PROJECT_NAME})
  else()
    get_filename_component(projectName ${dir} NAME)
  endif()
  xpParseDir(${dir} "")
  add_custom_target(${projectName} SOURCES ${${projectName}_srcs}) # creates utility project in MSVC
  set_property(TARGET ${projectName} PROPERTY FOLDER ${folder})
  xpSourceListAppend(${${projectName}_srcs})
endfunction()

macro(xpSourceListAppend)
  set(_dir ${CMAKE_CURRENT_SOURCE_DIR})
  if(EXISTS ${_dir}/CMakeLists.txt)
    list(APPEND masterSrcList ${_dir}/CMakeLists.txt)
  endif()
  file(GLOB msvcFiles "${_dir}/*.sln" "${_dir}/*.vcxproj" "${_dir}/*.vcxproj.filters")
  list(APPEND masterSrcList ${msvcFiles})
  if(${ARGC} GREATER 0)
    foreach(f ${ARGN})
      # remove any relative parts with get_filename_component call
      # as this will help REMOVE_DUPLICATES
      if(IS_ABSOLUTE ${f})
        get_filename_component(f ${f} ABSOLUTE)
      else()
        get_filename_component(f ${_dir}/${f} ABSOLUTE)
      endif()
      list(APPEND masterSrcList ${f})
    endforeach()
  else()
    file(GLOB miscFiles LIST_DIRECTORIES false
      ${_dir}/.git ${_dir}/.gitattributes ${_dir}/.gitmodules
      ${_dir}/*clang-format
      ${_dir}/README.md
      )
    list(APPEND masterSrcList ${miscFiles})
    file(RELATIVE_PATH relPath ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
    string(REPLACE "/" "" custTgt .CMake${relPath})
    add_custom_target(${custTgt} SOURCES ${miscFiles}) # creates utility project in MSVC
    set_property(TARGET ${custTgt} PROPERTY FOLDER ${folder})
  endif()
  if(EXISTS ${_dir}/.codereview)
    file(GLOB crFiles "${_dir}/.codereview/*")
    list(APPEND masterSrcList ${crFiles})
    file(RELATIVE_PATH relPath ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
    string(REPLACE "/" "" custTgt .codereview${relPath})
    if(NOT TARGET ${custTgt})
      add_custom_target(${custTgt} SOURCES ${crFiles}) # creates utility project in MSVC
      set_property(TARGET ${custTgt} PROPERTY FOLDER ${folder})
    endif()
  endif()
  if(NOT ${CMAKE_BINARY_DIR} STREQUAL ${CMAKE_CURRENT_BINARY_DIR})
    set(masterSrcList "${masterSrcList}" PARENT_SCOPE)
  else()
    list(REMOVE_DUPLICATES masterSrcList)
    if(EXISTS ${CMAKE_SOURCE_DIR}/.git)
      xpGitIgnoredDirs(ignoredDirs ${CMAKE_SOURCE_DIR} .git/)
      xpGitUntrackedFiles(untrackedFiles ${CMAKE_SOURCE_DIR})
      file(GLOB topdir ${_dir}/*)
      xpListAppendTrailingSlash(topdir ${topdir})
      list(REMOVE_ITEM topdir ${ignoredDirs} ${untrackedFiles})
      list(SORT topdir) # sort list in-place alphabetically
      foreach(item ${topdir})
        xpGlobFiles(repoFiles ${item} *)
        xpGlobFiles(fmtFiles ${item} *.c *.h *.cpp *.hpp *.cu *.cuh *.proto)
      endforeach()
      list(REMOVE_ITEM repoFiles ${masterSrcList})
      if(repoFiles)
        string(REPLACE ";" "\n" repoFiles "${repoFiles}")
        file(WRITE ${CMAKE_BINARY_DIR}/notincmake.txt ${repoFiles}\n)
        list(APPEND masterSrcList ${CMAKE_BINARY_DIR}/notincmake.txt)
      endif()
      ####
      # Windows can't handle passing very many files to clang-format
      if(NOT MSVC AND fmtFiles AND NOT ${CMAKE_PROJECT_NAME} STREQUAL externpro)
        # make paths relative to CMAKE_SOURCE_DIR
        xpListRemoveFromAll(fmtFiles ${CMAKE_SOURCE_DIR} . ${fmtFiles})
        list(LENGTH fmtFiles lenFmtFiles)
        xpGetPkgVar(clangformat EXE)
        add_custom_command(OUTPUT format_cmake
          COMMAND ${CLANGFORMAT_EXE} -style=file -i ${fmtFiles}
          WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
          COMMENT "Running clang-format on ${lenFmtFiles} files..."
          )
        string(REPLACE ";" "\n" fmtFiles "${fmtFiles}")
        file(WRITE ${CMAKE_BINARY_DIR}/formatfiles.txt ${fmtFiles}\n)
        add_custom_target(format SOURCES ${CMAKE_BINARY_DIR}/formatfiles.txt DEPENDS format_cmake)
        list(APPEND masterSrcList ${CMAKE_BINARY_DIR}/formatfiles.txt)
        set_property(TARGET format PROPERTY FOLDER CMakeTargets)
      endif()
    endif() # is a .git repo
    option(XP_CSCOPE "always update cscope database" OFF)
    if(XP_CSCOPE)
      file(GLOB cscope_files ${CMAKE_BINARY_DIR}/cscope.*)
      list(LENGTH cscope_files len)
      if(NOT ${len} EQUAL 0)
        file(REMOVE ${cscope_files})
      endif()
      string(REPLACE ";" "\n" cscopeFileList "${masterSrcList}")
      file(WRITE ${CMAKE_BINARY_DIR}/cscope.files ${cscopeFileList}\n)
      message(STATUS "Generating cscope database")
      execute_process(COMMAND cscope -b -q -k -i cscope.files)
    endif()
  endif()
endmacro()

function(xpTouchFiles fileList)
  option(XP_TOUCH_FILES "touch files with known warnings" OFF)
  if(NOT XP_TOUCH_FILES)
    return()
  endif()
  foreach(f ${fileList})
    execute_process(COMMAND ${CMAKE_COMMAND} -E touch_nocreate ${f}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      )
  endforeach()
endfunction()

function(xpFindPkg)
  cmake_parse_arguments(FP "" "" PKGS ${ARGN})
  foreach(pkg ${FP_PKGS})
    string(TOUPPER ${pkg} PKG)
    if(NOT ${PKG}_FOUND)
      string(TOLOWER ${pkg} pkg)
      unset(usexp-${pkg}_DIR CACHE)
      find_package(usexp-${pkg} REQUIRED PATHS ${XP_MODULE_PATH} NO_DEFAULT_PATH)
      mark_as_advanced(usexp-${pkg}_DIR)
      if(DEFINED ${PKG}_FOUND)
        list(APPEND reqVars ${PKG}_FOUND)
      else()
        message(AUTHOR_WARNING "${PKG}: no ${PKG}_FOUND defined")
      endif()
      foreach(var ${reqVars})
        set(${var} ${${var}} PARENT_SCOPE)
      endforeach()
    endif()
  endforeach()
endfunction()

function(xpGetPkgVar pkg)
  xpFindPkg(PKGS ${pkg})
  string(TOUPPER ${pkg} PKG)
  if(${PKG}_FOUND)
    foreach(var ${ARGN})
      string(TOUPPER ${var} VAR)
      if(DEFINED ${PKG}_${VAR})
        set(${PKG}_${VAR} ${${PKG}_${VAR}} PARENT_SCOPE)
      elseif(DEFINED ${pkg}_${VAR})
        set(${pkg}_${VAR} ${${pkg}_${VAR}} PARENT_SCOPE)
      elseif(DEFINED ${PKG}_${var})
        set(${PKG}_${var} ${${PKG}_${var}} PARENT_SCOPE)
      elseif(DEFINED ${pkg}_${var})
        set(${pkg}_${var} ${${pkg}_${var}} PARENT_SCOPE)
      endif()
    endforeach()
  endif()
endfunction()

# meant for internal consumption (called by xpGetExtern)
function(xpAppendPkgVars pkg _libList _incDirs)
  string(TOUPPER ${pkg} PKG)
  if(${PKG}_FOUND)
    if(DEFINED ${PKG}_LIBRARIES)
      list(APPEND liblist "${${PKG}_LIBRARIES}")
    endif()
    if(DEFINED ${PKG}_INCLUDE_DIR)
      foreach(idir ${${PKG}_INCLUDE_DIR})
        list(APPEND incdirs "$<BUILD_INTERFACE:${idir}>")
      endforeach()
    endif()
  endif()
  set(${_libList} ${liblist} PARENT_SCOPE)
  set(${_incDirs} ${incdirs} PARENT_SCOPE)
endfunction()

# get the external include directories and library list
# given the PUBLIC and PRIVATE packages passed in
function(xpGetExtern _incDirs _libList)
  set(multiValueArgs PUBLIC PRIVATE)
  cmake_parse_arguments(GE "" "" "${multiValueArgs}" ${ARGN})
  xpFindPkg(PKGS ${GE_PUBLIC} ${GE_PRIVATE})
  list(APPEND incdirs SYSTEM)
  if(DEFINED GE_PUBLIC)
    list(APPEND incdirs PUBLIC)
  endif()
  foreach(pkg ${GE_PUBLIC})
    xpAppendPkgVars(${pkg} liblist incdirs)
  endforeach()
  if(DEFINED GE_PRIVATE)
    list(APPEND incdirs PRIVATE)
  endif()
  foreach(pkg ${GE_PRIVATE})
    xpAppendPkgVars(${pkg} liblist incdirs)
  endforeach()
  if(DEFINED incdirs)
    list(REMOVE_DUPLICATES incdirs)
  endif()
  set(${_libList} ${liblist} PARENT_SCOPE)
  set(${_incDirs} ${incdirs} PARENT_SCOPE)
endfunction()

function(xpLibdepTest libName)
  if(MSVC)
    option(XP_GENERATE_LIBDEPS "include library dependency projects" OFF)
  else()
    return()
  endif()
  if(XP_GENERATE_LIBDEPS)
    set(depsName ${libName}Deps)
    set(fileName ${CMAKE_CURRENT_BINARY_DIR}/${libName}Deps.cpp)
    file(WRITE ${fileName}
      "// This target/project and file exist to help verify that all dependencies\n"
      "// are included in ${libName} and that there are no unresolved external symbols.\n"
      "//\n"
      "// Searching the code for 'pragma comment' (with a comment-type of lib) will\n"
      "// turn up a list of libraries passed to the linker (it's an MSVC way to\n"
      "// specify additional libraries to link in).\n"
      )
    source_group("" FILES ${fileName})
    add_library(${depsName} MODULE ${fileName})
    add_dependencies(${depsName} ${libName})
    target_link_libraries(${depsName} ${libName})
    set_property(TARGET ${depsName} PROPERTY FOLDER "${folder}/LibDeps")
  endif()
endfunction()

function(xpVerboseListing label thelist)
  message(STATUS "  ${label}")
  foreach(param ${thelist})
    message(STATUS "  ${param}")
  endforeach()
endfunction()

macro(xpCreateVersionString prefix)
  math(EXPR MAJOR "${${prefix}_VERSION_MAJOR} * 1000000")
  math(EXPR MINOR "${${prefix}_VERSION_MINOR} * 10000")
  math(EXPR PATCH "${${prefix}_VERSION_PATCH} * 100")
  math(EXPR ${prefix}_VERSION_NUM "${MAJOR} + ${MINOR} + ${PATCH} + ${${prefix}_VERSION_TWEAK}")
  set(${prefix}_STR "${${prefix}_VERSION_MAJOR}.${${prefix}_VERSION_MINOR}.${${prefix}_VERSION_PATCH}.${${prefix}_VERSION_TWEAK}")
endmacro()

# cmake-generates Version.hpp, resource.rc, resource.h in CMAKE_CURRENT_BINARY_DIR
function(xpGenerateResources iconPath generatedFiles)
  include(${CMAKE_BINARY_DIR}/version.cmake OPTIONAL)
  # in case there wasn't a version.cmake in CMAKE_BINARY_DIR
  include(${xpThisDir}/version.cmake)
  string(TIMESTAMP PACKAGE_CURRENT_YEAR %Y)
  # Creates PACKAGE_VERSION_NUM and PACKAGE_STR
  xpCreateVersionString(PACKAGE)
  # Creates FILE_VERSION_NUM and FILE_STR
  xpCreateVersionString(FILE)
  set(ICON_PATH ${iconPath})
  if(NOT DEFINED FILE_DESC)
    if(DEFINED PACKAGE_NAME AND DEFINED exe_name)
      set(FILE_DESC "${PACKAGE_NAME} ${exe_name}")
    elseif(DEFINED PACKAGE_NAME)
      set(FILE_DESC "${PACKAGE_NAME}")
    endif()
  endif()
  # NOTE: it appears that configure_file is smart enough that only if the input
  # file (or substituted variables) are modified does it re-configure the output
  # file; in other words, running cmake shouldn't cause needless rebuilds because
  # these files shouldn't be touched by cmake unless they need to be...
  configure_file(${xpThisDir}/Version.hpp.in ${CMAKE_CURRENT_BINARY_DIR}/Version.hpp)
  configure_file(${xpThisDir}/resource.rc.in ${CMAKE_CURRENT_BINARY_DIR}/resource.rc)
  configure_file(${xpThisDir}/resource.h.in ${CMAKE_CURRENT_BINARY_DIR}/resource.h)
  set(${generatedFiles}
    ${CMAKE_CURRENT_BINARY_DIR}/resource.h
    ${CMAKE_CURRENT_BINARY_DIR}/resource.rc
    ${CMAKE_CURRENT_BINARY_DIR}/Version.hpp
    PARENT_SCOPE
    )
endfunction()

function(xpCreateHeaderResource _output) # .hrc
  xpGetPkgVar(wxInclude EXE) # sets WXINCLUDE_EXE
  foreach(in ${ARGN})
    if(NOT IS_ABSOLUTE ${in})
      get_filename_component(in ${CMAKE_CURRENT_SOURCE_DIR}/${in} ABSOLUTE)
    endif()
    if(EXISTS ${in})
      get_filename_component(of ${in} NAME_WE)
      get_filename_component(nm ${in} NAME)
      get_filename_component(dr ${in} DIRECTORY)
      set(op ${CMAKE_CURRENT_BINARY_DIR}/Resources/${of}.hrc)
      add_custom_command(OUTPUT ${op}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/Resources
        COMMAND $<TARGET_FILE:${WXINCLUDE_EXE}> --const --appendtype --wxnone --respectcase --output-file=${op} ${nm}
        WORKING_DIRECTORY ${dr} DEPENDS ${in}
        )
      list(APPEND outList ${op})
    else()
      message(FATAL_ERROR "resource not found: ${in}")
    endif()
  endforeach()
  set(${_output} ${outList} PARENT_SCOPE)
endfunction()

function(xpGitCheckout url hash dir)
  if(NOT GIT_FOUND)
    include(FindGit)
    find_package(Git)
  endif()
  if(NOT GIT_FOUND)
    message(FATAL_ERROR "git not detected")
  endif()
  # if local git repo doesn't yet exist, clone, else fetch
  if(NOT EXISTS ${dir}/.git)
    message(STATUS "Cloning ${url} to ${dir}")
    execute_process(
      COMMAND ${GIT_EXECUTABLE} clone ${url} ${dir}
      ERROR_QUIET
      )
  else()
    message(STATUS "Fetching ${url} in ${dir}")
    execute_process(
      COMMAND ${GIT_EXECUTABLE} fetch --all
      WORKING_DIRECTORY ${dir}
      ERROR_QUIET
      )
  endif()
  # checkout specific hash
  message(STATUS "Checkout hash '${hash}'")
  execute_process(
    COMMAND ${GIT_EXECUTABLE} checkout ${hash}
    WORKING_DIRECTORY ${dir}
    ERROR_QUIET
    RESULT_VARIABLE result
    )
  if(result) # if hash is invalid...
    message(FATAL_ERROR "Failed to checkout: verify hash correct")
  endif()
  # warn developer if git repo is dirty
  execute_process(
    COMMAND ${GIT_EXECUTABLE} status --porcelain
    WORKING_DIRECTORY ${dir}
    ERROR_QUIET
    OUTPUT_VARIABLE dirty
    )
  if(dirty)
    message(AUTHOR_WARNING "git repo @ ${dir} dirty:\n${dirty}")
  endif()
endfunction()

function(xpPostBuildCopy theTarget copyList toPath)
  if(IS_ABSOLUTE ${toPath}) # absolute toPath
    set(dest ${toPath})
  else() # toPath is relative to target location
    set(dest $<TARGET_FILE_DIR:${theTarget}>/${toPath})
  endif()
  if(NOT EXISTS ${dest})
    add_custom_command(TARGET ${theTarget} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory ${dest})
  endif()
  foreach(_item ${copyList})
    # Handle target separately.
    if(TARGET ${_item})
      set(_item $<TARGET_FILE:${_item}>)
    endif()
    if(${_item} STREQUAL optimized)
      if(CMAKE_CONFIGURATION_TYPES)
        set(CONDITION1 IF $(Configuration)==Release)
        set(CONDITION2 IF $(Configuration)==RelWithDebInfo)
      endif()
    elseif(${_item} STREQUAL debug)
      if(CMAKE_CONFIGURATION_TYPES)
        set(CONDITION1 IF $(Configuration)==Debug)
      endif()
    else()
      if(IS_DIRECTORY ${_item})
        get_filename_component(dir ${_item} NAME)
        if(NOT EXISTS ${dest}/${dir})
          add_custom_command(TARGET ${theTarget} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory ${_item} ${dest}/${dir})
        endif()
      else()
        set(COPY_CMD ${CMAKE_COMMAND} -E copy_if_different ${_item} ${dest})
        if(CONDITION2)
          list(APPEND CONDITION1 "(")
          set(ELSECONDITION ")" ELSE "(" ${CONDITION2} "(" ${COPY_CMD} "))")
          set(CONDITION2)
        else()
          set(ELSECONDITION)
        endif()
        add_custom_command(TARGET ${theTarget} POST_BUILD
          COMMAND ${CONDITION1} ${COPY_CMD} ${ELSECONDITION})
      endif()
      set(CONDITION1)
    endif()
  endforeach()
endfunction()

function(xpPostBuildCopyDllLib theTarget toPath)
  if(IS_ABSOLUTE ${toPath}) # absolute toPath
    set(dest ${toPath})
  else() # toPath is relative to target location
    get_target_property(targetLoc ${theTarget} LOCATION)
    get_filename_component(dest ${targetLoc} PATH)
    set(dest ${dest}/${toPath})
  endif()
  if(NOT EXISTS ${dest})
    add_custom_command(TARGET ${theTarget} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory ${dest})
  endif()
  add_custom_command(TARGET ${theTarget} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      $<TARGET_FILE:${theTarget}> ${dest}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      $<TARGET_LINKER_FILE:${theTarget}> ${dest}
    )
endfunction()

function(xpEnforceOutOfSourceBuilds)
  # NOTE: could also check for in-source builds with the following:
  #if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
  # make sure the user doesn't play dirty with symlinks
  get_filename_component(srcdir "${CMAKE_SOURCE_DIR}" REALPATH)
  # check for polluted source tree and disallow in-source builds
  if(EXISTS ${srcdir}/CMakeCache.txt OR EXISTS ${srcdir}/CMakeFiles)
    message("##########################################################")
    message("Found results from an in-source build in source directory.")
    message("Please delete:")
    message("  ${srcdir}/CMakeCache.txt (file)")
    message("  ${srcdir}/CMakeFiles (directory)")
    message("And re-run CMake from an out-of-source directory.")
    message("In-source builds are forbidden!")
    message("##########################################################")
    message(FATAL_ERROR)
  endif()
endfunction()

function(xpOptionalBuildDirs)
  foreach(dir ${ARGV})
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${dir})
      string(TOUPPER ${dir} DIR)
      option(XP_GENERATE_${DIR} "include ${dir} targets" ON)
      if(XP_GENERATE_${DIR})
        set(${DIR} PARENT_SCOPE) # will be part of main solution
      else()
        set(${DIR} EXCLUDE_FROM_ALL PARENT_SCOPE) # generated, but not part of main solution
      endif()
    endif()
  endforeach()
endfunction()

function(xpCheckCompilerFlags flagVar flags)
  separate_arguments(flags)
  foreach(flag ${flags})
    string(REPLACE "-" "_" flag_ ${flag})
    string(REPLACE "=" "_" flag_ ${flag_})
    if(flagVar MATCHES ".*CXX_FLAGS.*")
      check_cxx_compiler_flag("${flag}" has_cxx${flag_})
      if(has_cxx${flag_})
        xpStringAppendIfDne(${flagVar} "${flag}")
      endif()
    elseif(flagVar MATCHES ".*C_FLAGS.*")
      check_c_compiler_flag("${flag}" has_c${flag_})
      if(has_c${flag_})
        xpStringAppendIfDne(${flagVar} "${flag}")
      endif()
    endif()
  endforeach()
  set(${flagVar} "${${flagVar}}" PARENT_SCOPE)
endfunction()

function(xpCheckLinkerFlag _FLAG _RESULT)
  set(srcFile ${CMAKE_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/CMakeTmp/linksrc.cxx)
  file(WRITE ${srcFile} "int main() { return 0; }\n")
  message(STATUS "Performing Linker Test ${_RESULT}")
  try_compile(${_RESULT} ${CMAKE_BINARY_DIR} ${srcFile}
    CMAKE_FLAGS -DCMAKE_EXE_LINKER_FLAGS="${_FLAG}"
    OUTPUT_VARIABLE OUTPUT
    )
  if(${${_RESULT}})
    message(STATUS "Performing Linker Test ${_RESULT} - Success")
  else()
    message(STATUS "Performing Linker Test ${_RESULT} - Failed")
  endif()
  set(${_RESULT} ${${_RESULT}} PARENT_SCOPE)
endfunction()

function(xpCheckLinkerOptions linkVar options)
  separate_arguments(options)
  foreach(opt ${options})
    string(REPLACE "-" "_" opt_ ${opt})
    string(REPLACE "," "" opt_ ${opt_})
    xpCheckLinkerFlag("${opt}" has_link${opt_})
    if(has_link${opt_})
      xpStringAppendIfDne(${linkVar} "${opt}")
    endif()
  endforeach()
  set(${linkVar} "${${linkVar}}" PARENT_SCOPE)
endfunction()

macro(xpEnableWarnings)
  if(CMAKE_COMPILER_IS_GNUCXX OR ${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
    check_cxx_compiler_flag("-Wall" has_Wall)
    if(has_Wall)
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wall")
    endif()
    #-Wall turns on maybe_uninitialized warnings which can be spurious
    check_cxx_compiler_flag("-Wno-maybe-uninitialized" has_Wno_maybe_uninitialized)
    if(has_Wno_maybe_uninitialized)
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wno-maybe-uninitialized")
    endif()
    check_cxx_compiler_flag("-Wextra" has_Wextra)
    if(has_Wextra)
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wextra")
    endif()
    check_cxx_compiler_flag("-Wcast-align" has_cast_align)
    if(has_cast_align)
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wcast-align")
    endif()
    check_cxx_compiler_flag("-pedantic" has_pedantic)
    if(has_pedantic)
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-pedantic")
    endif()
    check_cxx_compiler_flag("-Wformat=2" has_Wformat)
    if(has_Wformat)
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wformat=2")
    endif()
    check_cxx_compiler_flag("-Wfloat-equal" has_Wfloat_equal)
    if(has_Wfloat_equal)
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wfloat-equal")
    endif()
    check_cxx_compiler_flag("-Wno-unknown-pragmas" has_nounkprag)
    if(has_nounkprag)
      # turn off unknown pragma warnings as we use MSVC pragmas
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wno-unknown-pragmas")
    endif()
    check_cxx_compiler_flag("-Wno-psabi" has_psabi)
    if(has_psabi)
      # turn off messages noting ABI passing structure changes in GCC
      xpStringAppendIfDne(CMAKE_CXX_FLAGS "-Wno-psabi")
    endif()
  endif()
endmacro()

function(xpToggleDebugInfo)
  if(MSVC)
    set(releaseCompiler "/O2 /Ob2")
    set(reldebCompiler "/Zi /O2 /Ob1")
    set(releaseLinker "/INCREMENTAL:NO")
    set(reldebLinker "/debug /INCREMENTAL")
  elseif(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX OR
         ${CMAKE_C_COMPILER_ID} MATCHES "Clang" OR ${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
    set(releaseCompiler "-O3")
    set(reldebCompiler "-O2 -g")
  else()
    message(FATAL_ERROR "unknown compiler")
  endif()
  if(XP_BUILD_WITH_DEBUG_INFO)
    set(from release)
    set(to reldeb)
  else()
    set(from reldeb)
    set(to release)
  endif()
  foreach(flagVar ${ARGV})
    if(DEFINED ${flagVar})
      if(${flagVar} MATCHES ".*LINKER_FLAGS.*")
        if(DEFINED ${from}Linker AND DEFINED ${to}Linker)
          string(REGEX REPLACE "${${from}Linker}" "${${to}Linker}" flagTmp "${${flagVar}}")
          set(${flagVar} ${flagTmp} CACHE STRING "Flags used by the linker." FORCE)
        endif()
      else()
        if(${flagVar} MATCHES ".*CXX_FLAGS.*")
          set(cType "C++ ")
        elseif(${flagVar} MATCHES ".*C_FLAGS.*")
          set(cType "C ")
        endif()
        string(REGEX REPLACE "${${from}Compiler}" "${${to}Compiler}" flagTmp "${${flagVar}}")
        set(${flagVar} ${flagTmp} CACHE STRING "Flags used by the ${cType}compiler." FORCE)
      endif()
    endif()
  endforeach()
endfunction()

function(xpDebugInfoOption)
  option(XP_BUILD_WITH_DEBUG_INFO "build Release with debug information" OFF)
  if(DEFINED CMAKE_BUILD_TYPE)
    if(CMAKE_BUILD_TYPE STREQUAL Release)
      set_property(CACHE XP_BUILD_WITH_DEBUG_INFO PROPERTY TYPE BOOL)
    else()
      set_property(CACHE XP_BUILD_WITH_DEBUG_INFO PROPERTY TYPE INTERNAL)
    endif()
  endif()
  set(checkflags
    CMAKE_C_FLAGS_RELEASE
    CMAKE_CXX_FLAGS_RELEASE
    )
  if(MSVC)
    list(APPEND checkflags
      CMAKE_EXE_LINKER_FLAGS_RELEASE
      CMAKE_MODULE_LINKER_FLAGS_RELEASE
      CMAKE_SHARED_LINKER_FLAGS_RELEASE
      )
  endif()
  xpToggleDebugInfo(${checkflags})
endfunction()

function(xpModifyRuntime)
  if(XP_BUILD_STATIC_RT)
    set(from "/MD")
    set(to "/MT")
  else()
    set(from "/MT")
    set(to "/MD")
  endif()
  foreach(flagVar ${ARGV})
    if(DEFINED ${flagVar})
      if(${flagVar} MATCHES "${from}")
        string(REGEX REPLACE "${from}" "${to}" flagTmp "${${flagVar}}")
        if(${flagVar} MATCHES ".*CXX_FLAGS.*")
          set(cType "C++ ")
        elseif(${flagVar} MATCHES ".*C_FLAGS.*")
          set(cType "C ")
        endif()
        set(${flagVar} ${flagTmp} CACHE STRING "Flags used by the ${cType}compiler." FORCE)
      endif()
    endif()
  endforeach()
endfunction()

function(xpSetPostfix)
  if(XP_BUILD_STATIC_RT)
    set(CMAKE_RELEASE_POSTFIX "-s" PARENT_SCOPE)
    set(CMAKE_DEBUG_POSTFIX "-sd" PARENT_SCOPE)
  else()
    set(CMAKE_RELEASE_POSTFIX "" PARENT_SCOPE)
    set(CMAKE_DEBUG_POSTFIX "-d" PARENT_SCOPE)
  endif()
endfunction()

macro(xpCommonFlags)
  if(NOT DEFINED CMAKE_CXX_COMPILER_ID)
    set(CMAKE_CXX_COMPILER_ID NOTDEFINED)
  endif()
  include(${xpThisDir}/xpopts.cmake) # determine XP_BUILD_STATIC_RT
  xpSetPostfix()
  xpDebugInfoOption()
  if(MSVC)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
      add_definitions(-DWIN64)
    endif()
    # Turn on Multi-processor Compilation
    xpStringAppendIfDne(CMAKE_C_FLAGS "/MP")
    xpStringAppendIfDne(CMAKE_CXX_FLAGS "/MP")
    # Remove /Zm1000 - breaks optimizing compiler w/ IncrediBuild
    string(REPLACE "/Zm1000" "" CMAKE_C_FLAGS ${CMAKE_C_FLAGS})
    string(REPLACE "/Zm1000" "" CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
    if(CMAKE_CONFIGURATION_TYPES)
      # by default we'll modify the following list of flag variables,
      # but you can call xpModifyRuntime with your own list
      xpModifyRuntime(
        CMAKE_C_FLAGS_RELEASE
        CMAKE_C_FLAGS_DEBUG
        CMAKE_CXX_FLAGS_RELEASE
        CMAKE_CXX_FLAGS_DEBUG
        # NOTE: these are the only flags we modify in common (including externpro-built projects), for now
        )
    endif()
  elseif(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX OR ${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
    # C/C++
    if(CMAKE_BUILD_TYPE STREQUAL Debug)
      add_definitions(-D_DEBUG)
    endif()
    include(CheckCCompilerFlag)
    if(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
      # Solaris hard-coded to 64-bit compile
      # The check below fails on *linking* unless the flag is already set
      # (CMAKE_EXE_LINKER_FLAGS has no effect, either)
      xpStringAppendIfDne(CMAKE_C_FLAGS "-m64")
      check_c_compiler_flag("-m64" has_c_m64)
      if(!has_c_m64)
        message(SEND_ERROR "64-bit c build not supported")
      endif()
      xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-m64")
      xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-m64")
      xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-m64")
    endif() # CMAKE_SYSTEM_NAME (SunOS)
    check_c_compiler_flag("-fPIC" has_c_fPIC)
    if(has_c_fPIC)
      xpStringAppendIfDne(CMAKE_C_FLAGS "-fPIC")
      xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-fPIC")
      xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-fPIC")
      xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-fPIC")
    endif()
    check_c_compiler_flag("-msse3" has_c_msse3)
    if(has_c_msse3)
      xpStringAppendIfDne(CMAKE_C_FLAGS "-msse3")
    endif()
    check_c_compiler_flag("-fstack-protector-strong" has_c_StrongSP)
    if(has_c_StrongSP)
      xpStringAppendIfDne(CMAKE_C_FLAGS "-fstack-protector-strong")
    endif()
    if(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
      include(CheckLibraryExists)
      check_library_exists(ssp __stack_chk_guard "" HAVE_LIB_SSP)
      if(has_c_StrongSP AND HAVE_LIB_SSP)
        xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-lssp")
        xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-lssp")
        xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-lssp")
      endif()
      # Libumem is a library used to detect memory management bugs in applications.
      # It's available as a standard part of Solaris from Solaris 9 Update 3 onwards.
      # Functions in this library provide fast, scalable object-caching memory
      # allocation with multithreaded application support.
      check_library_exists(umem umem_alloc "" HAVE_LIB_UMEM)
      if(HAVE_LIB_UMEM)
        xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-lumem")
        xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-lumem")
        xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-lumem")
      endif(HAVE_LIB_UMEM)
      # curl needs _REENTRANT defined for errno calls to work (Solaris only)
      add_definitions(-D_REENTRANT)
    endif() # CMAKE_SYSTEM_NAME (SunOS)
    # C++
    if(CMAKE_COMPILER_IS_GNUCXX OR ${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
      include(CheckCXXCompilerFlag)
      if(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
        # see comment above for CMAKE_C_FLAGS "-m64"
        # TRICKY: this needs to be done before any other check_cxx_compiler_flag calls
        xpStringAppendIfDne(CMAKE_CXX_FLAGS "-m64")
        check_cxx_compiler_flag("-m64" has_cxx_m64)
        if(!has_cxx_m64)
          message(SEND_ERROR "64-bit cxx build not supported")
        endif()
      endif() # CMAKE_SYSTEM_NAME (SunOS)
      if(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
        check_cxx_compiler_flag("-stdlib=libc++" has_libcxx)
        if(has_libcxx)
          xpStringAppendIfDne(CMAKE_CXX_FLAGS "-stdlib=libc++")
          xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-stdlib=libc++")
          xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-stdlib=libc++")
          xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-stdlib=libc++")
        endif()
      endif()
      check_cxx_compiler_flag("-std=c++14" has_cxx14) # should be available gcc >= 4.9
      if(has_cxx14)
        xpStringAppendIfDne(CMAKE_CXX_FLAGS "-std=c++14")
      else()
        check_cxx_compiler_flag("-std=c++11" has_cxx11) # should be available gcc >= 4.7
        if(has_cxx11)
          xpStringAppendIfDne(CMAKE_CXX_FLAGS "-std=c++11")
        else()
          check_cxx_compiler_flag("-std=c++0x" has_cxx0x)
          if(has_cxx0x)
            xpStringAppendIfDne(CMAKE_CXX_FLAGS "-std=c++0x")
          endif()
        endif()
      endif()
      check_cxx_compiler_flag("-fPIC" has_cxx_fPIC)
      if(has_cxx_fPIC)
        xpStringAppendIfDne(CMAKE_CXX_FLAGS "-fPIC")
        xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-fPIC")
        xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-fPIC")
        xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-fPIC")
      endif()
      check_cxx_compiler_flag("-msse3" has_cxx_msse3)
      if(has_cxx_msse3)
        xpStringAppendIfDne(CMAKE_CXX_FLAGS "-msse3")
      endif()
      check_cxx_compiler_flag("-fstack-protector-strong" has_cxx_StrongSP)
      if(has_cxx_StrongSP)
        xpStringAppendIfDne(CMAKE_CXX_FLAGS "-fstack-protector-strong")
      endif()
      if(${CMAKE_SYSTEM_NAME} STREQUAL "SunOS")
        check_library_exists(ssp __stack_chk_guard "" HAVE_LIB_SSP)
        if(has_cxx_StrongSP AND HAVE_LIB_SSP)
          xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-lssp")
          xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-lssp")
          xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-lssp")
        endif()
      endif() # CMAKE_SYSTEM_NAME (SunOS)
      if(${CMAKE_SYSTEM_NAME} STREQUAL "Darwin")
        check_cxx_compiler_flag("-arch x86_64" has_cxx_arch)
        if(has_cxx_arch)
          xpStringAppendIfDne(CMAKE_CXX_FLAGS "-arch x86_64")
          xpStringAppendIfDne(CMAKE_EXE_LINKER_FLAGS "-arch x86_64")
          xpStringAppendIfDne(CMAKE_MODULE_LINKER_FLAGS "-arch x86_64")
          xpStringAppendIfDne(CMAKE_SHARED_LINKER_FLAGS "-arch x86_64")
        endif()
        check_c_compiler_flag("-arch x86_64" has_c_arch)
        if(has_c_arch)
          xpStringAppendIfDne(CMAKE_C_FLAGS "-arch x86_64")
        endif()
      endif() # CMAKE_SYSTEM_NAME (Darwin)
    endif() # C++ (GNUCXX OR Clang)
  endif()
endmacro()
