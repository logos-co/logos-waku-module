cmake_minimum_required(VERSION 3.14)
project(WakuModulePlugin LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_AUTOMOC ON)

option(LOGOS_WAKU_MODULE_USE_VENDOR "Force use of vendored Logos dependencies" OFF)

set(_parent_liblogos "${CMAKE_SOURCE_DIR}/../logos-liblogos")
set(_parent_cpp_sdk "${CMAKE_SOURCE_DIR}/../logos-cpp-sdk")
set(_use_vendor ${LOGOS_WAKU_MODULE_USE_VENDOR})
if(NOT _use_vendor)
    if(NOT EXISTS "${_parent_liblogos}/interface.h" OR NOT EXISTS "${_parent_cpp_sdk}/cpp/logos_api.h")
        set(_use_vendor ON)
    endif()
endif()

if(_use_vendor)
    set(LOGOS_LIBLOGOS_ROOT "${CMAKE_SOURCE_DIR}/vendor/logos-liblogos")
    set(LOGOS_CPP_SDK_ROOT "${CMAKE_SOURCE_DIR}/vendor/logos-cpp-sdk")
else()
    set(LOGOS_LIBLOGOS_ROOT "${_parent_liblogos}")
    set(LOGOS_CPP_SDK_ROOT "${_parent_cpp_sdk}")
endif()

if(NOT EXISTS "${LOGOS_LIBLOGOS_ROOT}/interface.h")
    message(FATAL_ERROR "logos-liblogos not found. Run git submodule update --init --recursive.")
endif()

if(NOT EXISTS "${LOGOS_CPP_SDK_ROOT}/cpp/logos_api.h")
    message(FATAL_ERROR "logos-cpp-sdk not found. Run git submodule update --init --recursive.")
endif()

set(NWAKU_ROOT "${CMAKE_SOURCE_DIR}/vendor/nwaku")
if(NOT EXISTS "${NWAKU_ROOT}/Makefile")
    message(FATAL_ERROR "nwaku vendor not found. Run git submodule update --init --recursive.")
endif()

get_filename_component(LOGOS_DEPS_ROOT "${LOGOS_CPP_SDK_ROOT}" DIRECTORY)

if(NOT DEFINED QT_VERSION_MAJOR)
    find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core RemoteObjects)
    if(Qt6_FOUND)
        set(QT_VERSION_MAJOR 6)
    else()
        set(QT_VERSION_MAJOR 5)
    endif()
endif()
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core RemoteObjects)

set(CPP_GENERATOR_BUILD_DIR "${LOGOS_DEPS_ROOT}/build/cpp-generator")
set(CPP_GENERATOR "${CPP_GENERATOR_BUILD_DIR}/bin/logos-cpp-generator")
set(METADATA_JSON "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json")
set(PLUGINS_OUTPUT_DIR "${CMAKE_BINARY_DIR}/modules")

if(NOT TARGET cpp_generator_build)
    add_custom_target(cpp_generator_build
        COMMAND bash "${LOGOS_CPP_SDK_ROOT}/cpp-generator/compile.sh"
        WORKING_DIRECTORY "${LOGOS_DEPS_ROOT}"
        COMMENT "Building logos-cpp-generator via ${LOGOS_CPP_SDK_ROOT}/cpp-generator/compile.sh"
        VERBATIM
    )
endif()

add_custom_target(run_cpp_generator_waku
    COMMAND "${CPP_GENERATOR}" --metadata "${METADATA_JSON}" --module-dir "${PLUGINS_OUTPUT_DIR}"
    WORKING_DIRECTORY "${LOGOS_DEPS_ROOT}"
    COMMENT "Running logos-cpp-generator on ${METADATA_JSON} with module-dir ${PLUGINS_OUTPUT_DIR}"
    VERBATIM
)
add_dependencies(run_cpp_generator_waku cpp_generator_build)

set(LIBWAKU_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(LIBWAKU_NAMES libwaku.so libwaku.dylib libwaku.dll waku.dll)
find_library(LIBWAKU_PATH
    NAMES ${LIBWAKU_NAMES}
    PATHS ${LIBWAKU_DIR}
    NO_DEFAULT_PATH
)

if(NOT LIBWAKU_PATH)
    message(WARNING "libwaku not found in lib/. Build it via build_libwaku.sh before linking.")
endif()

set(PLUGIN_SOURCES
    waku_module_plugin.cpp
    waku_module_plugin.h
    waku_module_interface.h
    ${LOGOS_LIBLOGOS_ROOT}/interface.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_client.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_client.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_consumer.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_consumer.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_provider.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/logos_api_provider.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/token_manager.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/token_manager.h
    ${LOGOS_CPP_SDK_ROOT}/cpp/module_proxy.cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/module_proxy.h
)

add_library(waku_module_plugin SHARED ${PLUGIN_SOURCES})
set_target_properties(waku_module_plugin PROPERTIES
    PREFIX "")

add_dependencies(waku_module_plugin run_cpp_generator_waku)

target_link_libraries(waku_module_plugin PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::RemoteObjects
)
if(LIBWAKU_PATH)
    target_link_libraries(waku_module_plugin PRIVATE ${LIBWAKU_PATH})
endif()

target_include_directories(waku_module_plugin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LIBWAKU_DIR}
    ${LOGOS_LIBLOGOS_ROOT}
    ${LOGOS_CPP_SDK_ROOT}/cpp
    ${LOGOS_CPP_SDK_ROOT}/cpp/generated
)

set_target_properties(waku_module_plugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/modules"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/modules"  # For Windows .dll
    BUILD_WITH_INSTALL_RPATH TRUE
    SKIP_BUILD_RPATH FALSE)

if(APPLE)
    set_target_properties(waku_module_plugin PROPERTIES
        INSTALL_RPATH "@loader_path"
        INSTALL_NAME_DIR "@rpath"
        BUILD_WITH_INSTALL_NAME_DIR TRUE)

    if(LIBWAKU_PATH)
        get_filename_component(LIBWAKU_FILENAME "${LIBWAKU_PATH}" NAME)
        add_custom_command(TARGET waku_module_plugin PRE_LINK
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${LIBWAKU_PATH}
                ${CMAKE_BINARY_DIR}/modules/${LIBWAKU_FILENAME}
            COMMENT "Copying ${LIBWAKU_FILENAME} to modules directory"
        )

        add_custom_command(TARGET waku_module_plugin POST_BUILD
            COMMAND install_name_tool -id "@rpath/waku_module_plugin.dylib" $<TARGET_FILE:waku_module_plugin>
            COMMAND install_name_tool -change "${LIBWAKU_PATH}" "@rpath/${LIBWAKU_FILENAME}" $<TARGET_FILE:waku_module_plugin>
            COMMAND install_name_tool -id "@rpath/${LIBWAKU_FILENAME}" "${CMAKE_BINARY_DIR}/modules/${LIBWAKU_FILENAME}"
            COMMENT "Updating library paths for macOS"
        )
    else()
        add_custom_command(TARGET waku_module_plugin POST_BUILD
            COMMAND install_name_tool -id "@rpath/waku_module_plugin.dylib" $<TARGET_FILE:waku_module_plugin>
            COMMENT "Updating library paths for macOS (libwaku not found)"
        )
    endif()
else()
    set_target_properties(waku_module_plugin PROPERTIES
        INSTALL_RPATH "$ORIGIN"
        INSTALL_RPATH_USE_LINK_PATH FALSE)

    if(LIBWAKU_PATH)
        get_filename_component(LIBWAKU_FILENAME "${LIBWAKU_PATH}" NAME)
        add_custom_command(TARGET waku_module_plugin PRE_LINK
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${LIBWAKU_PATH}
                ${CMAKE_BINARY_DIR}/modules/${LIBWAKU_FILENAME}
            COMMENT "Copying ${LIBWAKU_FILENAME} to modules directory"
        )
    endif()
endif()

install(TARGETS waku_module_plugin
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/logos/modules
    RUNTIME DESTINATION ${CMAKE_INSTALL_LIBDIR}/logos/modules
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/logos/modules
)

install(FILES ${METADATA_JSON}
    DESTINATION ${CMAKE_INSTALL_DATADIR}/logos-waku-module
)

install(DIRECTORY "${PLUGINS_OUTPUT_DIR}/"
    DESTINATION ${CMAKE_INSTALL_DATADIR}/logos-waku-module/generated
    OPTIONAL
)
