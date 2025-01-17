# jasper
xpProOption(jasper DBG)
set(VER 1.900.1)
set(REPO github.com/mdadams/jasper)
set(FORK github.com/smanders/jasper)
set(PRO_JASPER
  NAME jasper
  WEB "JasPer" http://www.ece.uvic.ca/~frodo/jasper/ "JasPer website"
  LICENSE "open" "http://www.ece.uvic.ca/~frodo/jasper/#license" "JasPer License (based on MIT license)"
  DESC "JPEG 2000 Part-1 codec implementation"
  REPO "repo" https://${FORK} "forked jasper repo on github"
  VER ${VER}
  GIT_UPSTREAM https://${REPO}.git
  GIT_ORIGIN https://${FORK}.git
  GIT_TAG xp-${VER} # what to 'git checkout'
  GIT_REF version-${VER} # create patch from this tag to 'git checkout'
  DLURL http://www.ece.uvic.ca/~frodo/jasper/software/jasper-${VER}.zip
  DLMD5 a342b2b4495b3e1394e161eb5d85d754
  PATCH ${PATCH_DIR}/jasper.patch
  DIFF https://${FORK}/compare/
  )
########################################
function(build_jasper)
  if(NOT (XP_DEFAULT OR XP_PRO_JASPER))
    return()
  endif()
  xpGetArgValue(${PRO_JASPER} ARG VER VALUE VER)
  set(XP_CONFIGURE -DXP_NAMESPACE:STRING=xpro -DJASPER_VER=${VER})
  configure_file(${PRO_DIR}/use/usexp-jasper-config.cmake ${STAGE_DIR}/share/cmake/
    @ONLY NEWLINE_STYLE LF
    )
  xpCmakeBuild(jasper "" "${XP_CONFIGURE}")
endfunction()
