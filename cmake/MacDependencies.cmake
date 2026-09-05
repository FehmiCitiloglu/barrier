# Fail at configure time instead of silently selecting the other Homebrew tree.
function(barrier_check_architecture library)
    if (NOT EXISTS "${library}")
        message(FATAL_ERROR "Missing macOS dependency: ${library}")
    endif()
    foreach(arch ${CMAKE_OSX_ARCHITECTURES})
        execute_process(COMMAND lipo "${library}" -verify_arch "${arch}"
                        RESULT_VARIABLE result ERROR_VARIABLE detail)
        if (NOT result EQUAL 0)
            message(FATAL_ERROR "Dependency ${library} does not contain ${arch}: ${detail}. Select matching CMAKE_PREFIX_PATH / OPENSSL_ROOT_DIR.")
        endif()
    endforeach()
endfunction()
