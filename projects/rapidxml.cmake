# RapidXml
# http://sourceforge.net/projects/rapidxml/files/rapidxml/
xpProOption(rapidxml)
set(VER 1.13)
set(REPO github.com/smanders/rapidxml)
set(PRO_RAPIDXML
  NAME rapidxml
  WEB "RapidXml" http://rapidxml.sourceforge.net/ "RapidXml on sourceforge"
  LICENSE "open" http://rapidxml.sourceforge.net/license.txt "Boost Software License -or- The MIT License"
  DESC "fast XML parser"
  REPO "repo" https://${REPO} "rapidxml repo on github"
  VER ${VER}
  GIT_ORIGIN https://${REPO}.git
  GIT_TAG xp${VER} # what to 'git checkout'
  GIT_REF v${VER} # create patch from this tag to 'git checkout'
  DLURL http://downloads.sourceforge.net/project/rapidxml/rapidxml/rapidxml%20${VER}/rapidxml-${VER}.zip
  DLMD5 7b4b42c9331c90aded23bb55dc725d6a
  PATCH ${PATCH_DIR}/rapidxml.patch
  DIFF https://${REPO}/compare/
  )
########################################
function(build_rapidxml)
  if(NOT (XP_DEFAULT OR XP_PRO_RAPIDXML))
    return()
  endif()
  xpGetArgValue(${PRO_RAPIDXML} ARG NAME VALUE NAME)
  xpGetArgValue(${PRO_RAPIDXML} ARG VER VALUE VER)
  set(LIBRARY_HDR xpro::${NAME})
  set(LIBRARY_INCLUDEDIRS include/${NAME}_${VER})
  configure_file(${PRO_DIR}/use/usexp-template-hdr-config.cmake
    ${STAGE_DIR}/share/cmake/usexp-${NAME}-config.cmake
    @ONLY NEWLINE_STYLE LF
    )
  ExternalProject_Get_Property(${NAME} SOURCE_DIR)
  ExternalProject_Add(${NAME}_bld DEPENDS ${NAME}
    DOWNLOAD_COMMAND "" DOWNLOAD_DIR ${NULL_DIR} CONFIGURE_COMMAND ""
    SOURCE_DIR ${SOURCE_DIR} BINARY_DIR ${NULL_DIR} INSTALL_DIR ${NULL_DIR}
    BUILD_COMMAND ${CMAKE_COMMAND} -E copy_directory
      <SOURCE_DIR> ${STAGE_DIR}/${LIBRARY_INCLUDEDIRS}/${NAME}
    INSTALL_COMMAND ""
    )
  set_property(TARGET ${NAME}_bld PROPERTY FOLDER ${bld_folder})
  message(STATUS "target ${NAME}_bld")
endfunction()
