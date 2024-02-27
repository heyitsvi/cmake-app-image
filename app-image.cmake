set(app_image_module_root ${CMAKE_CURRENT_LIST_DIR})

if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
  set(app_image_arch aarch64)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
  set(app_image_arch x86_64)
else()
  message(FATAL_ERROR "Unsupported AppImage architecture '${CMAKE_SYSTEM_PROCESSOR}'")
endif()

set(app_image_download_base "https://github.com/AppImage/AppImageKit/releases/download")

set(app_image_download_release "13")

function(download_app_image_run)
  cmake_parse_arguments(
    PARSE_ARGV 0 ARGV "" "DESTINATION" ""
  )

  cmake_path(ABSOLUTE_PATH ARGV_DESTINATION BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" NORMALIZE)

  file(
    DOWNLOAD "${app_image_download_base}/${app_image_download_release}/AppRun-${app_image_arch}"
    "${ARGV_DESTINATION}"
    LOG log
  )

  file(CHMOD "${ARGV_DESTINATION}" PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ)

  message(STATUS "${log}")
endfunction()

function(download_app_image_tool)
  cmake_parse_arguments(
    PARSE_ARGV 0 ARGV "" "DESTINATION" ""
  )

  cmake_path(ABSOLUTE_PATH ARGV_DESTINATION BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" NORMALIZE)

  file(
    DOWNLOAD "${app_image_download_base}/${app_image_download_release}/appimagetool-${app_image_arch}.AppImage"
    "${ARGV_DESTINATION}"
    LOG log
  )

  file(CHMOD "${ARGV_DESTINATION}" PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ)

  message(STATUS "${log}")
endfunction()

function(add_app_image target)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "DESTINATION;NAME;ICON;TARGET;EXECUTABLE;APP_DIR" "CATEGORIES"
  )

  download_app_image_tool(DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/appimagetool.AppImage")

  set(app_image_tool "${CMAKE_CURRENT_BINARY_DIR}/appimagetool.AppImage")

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION ${ARGV_NAME}.AppImage)
  endif()

  cmake_path(ABSOLUTE_PATH ARGV_DESTINATION BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" NORMALIZE)

  if(ARGV_APP_DIR)
    cmake_path(ABSOLUTE_PATH ARGV_APP_DIR BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" NORMALIZE)
  else()
    cmake_path(REMOVE_EXTENSION ARGV_DESTINATION LAST_ONLY OUTPUT_VARIABLE ARGV_APP_DIR)

    string(APPEND ARGV_APP_DIR ".AppDir")
  endif()

  if(ARGV_ICON)
    cmake_path(ABSOLUTE_PATH ARGV_ICON NORMALIZE)
  endif()

  if(ARGV_TARGET)
    set(ARGV_EXECUTABLE $<TARGET_FILE:${ARGV_TARGET}>)

    set(ARGV_EXECUTABLE_NAME $<TARGET_FILE_NAME:${ARGV_TARGET}>)
  else()
    cmake_path(ABSOLUTE_PATH ARGV_EXECUTABLE NORMALIZE)

    cmake_path(GET ARGV_EXECUTABLE FILENAME ARGV_EXECUTABLE_NAME)
  endif()

  download_app_image_run(DESTINATION "${ARGV_APP_DIR}/AppRun")

  list(JOIN ARGV_CATEGORIES ";" ARGV_CATEGORIES)

  file(READ "${app_image_module_root}/App.desktop" template)

  string(CONFIGURE "${template}" template)

  file(GENERATE OUTPUT "${ARGV_APP_DIR}/${ARGV_NAME}.desktop" CONTENT "${template}" NEWLINE_STYLE UNIX)

  if(ARGV_ICON)
    configure_file("${ARGV_ICON}" "${ARGV_APP_DIR}/icon.png" COPYONLY)
  endif()

  add_custom_target(
    ${target}_bin
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${ARGV_EXECUTABLE}" "${ARGV_APP_DIR}/usr/bin/${ARGV_EXECUTABLE_NAME}"
  )

  list(APPEND ARGV_DEPENDS ${target}_bin)

  add_custom_command(
    OUTPUT "${ARGV_DESTINATION}"
    COMMAND "${app_image_tool}" --no-appstream "${ARGV_APP_DIR}" "${ARGV_DESTINATION}"
    DEPENDS ${ARGV_DEPENDS}
  )

  add_custom_target(
    ${target}
    ALL
    DEPENDS "${ARGV_DESTINATION}"
  )
endfunction()
