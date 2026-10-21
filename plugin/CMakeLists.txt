find_package(Qt6 REQUIRED COMPONENTS ShaderTools Core Qml Gui Quick QuickControls2 Concurrent Sql Network DBus Multimedia)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WaylandClient IMPORTED_TARGET wayland-client REQUIRED)
pkg_check_modules(XkbCommon IMPORTED_TARGET xkbcommon REQUIRED)
pkg_check_modules(Qalculate IMPORTED_TARGET libqalculate REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Aubio IMPORTED_TARGET aubio REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
set(PROTOCOL_DIR "${CMAKE_CURRENT_BINARY_DIR}/protocols")
file(MAKE_DIRECTORY "${PROTOCOL_DIR}")
set(PROTOCOL_SOURCES)
foreach(PROTOCOL wlr-output-power-management-unstable-v1 ext-image-copy-capture-v1 ext-image-capture-source-v1 ext-foreign-toplevel-list-v1)
    set(XML "${CMAKE_CURRENT_SOURCE_DIR}/protocols/${PROTOCOL}.xml")
    add_custom_command(OUTPUT "${PROTOCOL_DIR}/${PROTOCOL}-client.h"
        COMMAND ${WAYLAND_SCANNER} client-header ${XML} "${PROTOCOL_DIR}/${PROTOCOL}-client.h" DEPENDS ${XML})
    add_custom_command(OUTPUT "${PROTOCOL_DIR}/${PROTOCOL}.c"
        COMMAND ${WAYLAND_SCANNER} private-code ${XML} "${PROTOCOL_DIR}/${PROTOCOL}.c" DEPENDS ${XML})
    list(APPEND PROTOCOL_SOURCES "${PROTOCOL_DIR}/${PROTOCOL}.c" "${PROTOCOL_DIR}/${PROTOCOL}-client.h")
endforeach()
add_library(caelestia-protocols STATIC ${PROTOCOL_SOURCES})
set_target_properties(caelestia-protocols PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(caelestia-protocols PUBLIC "${PROTOCOL_DIR}")
target_link_libraries(caelestia-protocols PUBLIC PkgConfig::WaylandClient)

include(cmake/sensorslib.cmake)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

include(cmake/pch.cmake)
include(cmake/qml-module.cmake)

# Header only helpers
add_library(caelestia-util INTERFACE)
target_include_directories(caelestia-util INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

add_subdirectory(3rdparty/rgbcx)
add_subdirectory(src/Caelestia)
