# glew
set(VER ${GLEW_BLDVER})
xpProOption(glew_${VER} DBG)
set(GLLN http://glew.sourceforge.net)
set(GLDL https://downloads.sourceforge.net/project/glew/glew/${VER})
set(REPO github.com/nigels-com/glew)
set(FORK github.com/smanders/glew)
set(PRO_GLEW_${VER}
  NAME glew_${VER}
  WEB "GLEW" ${GLLN} "GLEW on sourceforge.net"
  LICENSE "open" ${GLLN}/credits.html "Modified BSD, Mesa 3-D (MIT), and Khronos (MIT)"
  DESC "The OpenGL Extension Wrangler Library"
  REPO "repo" https://${REPO} "GLEW repo on github"
  VER ${VER}
  GIT_ORIGIN https://${FORK}.git
  GIT_UPSTREAM https://${REPO}.git
  GIT_TAG xp-${VER}
  GIT_REF glew-${VER}
  DLURL ${GLDL}/glew-${VER}.tgz
  DLMD5 7cbada3166d2aadfc4169c4283701066
  PATCH ${PATCH_DIR}/glew_${VER}.patch
  DIFF https://${FORK}/compare/nigels-com:
  BUILD_FUNC build_glew_bldver
  )
########################################
function(build_glew_bldver)
  set(gl_VER ${GLEW_BLDVER})
  if(NOT (XP_DEFAULT OR XP_PRO_GLEW_${gl_VER}))
    return()
  endif()
  set(XP_CONFIGURE
    -DGLEW_VER=${gl_VER}
    -DBUILD_UTILS=OFF
    -DBUILD_SHARED_LIBS=OFF
    -DINSTALL_PKGCONFIG=OFF
    )
  xpCmakeBuild(glew_${gl_VER} "" "${XP_CONFIGURE}")
endfunction()
