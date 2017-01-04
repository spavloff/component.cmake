cmake_minimum_required(VERSION 3.4)
include(CMakeParseArguments)

# Prepares build environment for using the specified component
#
# Arguments:
#    component_name - a component name like "number-recognizer"
#
# Reads variables:
#    EXTERNAL_LIBRARY_FOLDER - contains name of a folder in IDE, which
#                              will contain folder with component sources.
#                              If it is absent, default name is used.
#
# Result: 
#   Sets variables (for a component "number-recognizer"):
#     NumberRecognizer_library_folder - IDE folder for the component sources.
#     NumberRecognizer_test_folder    - IDE folder for the component unit tests.
#     NumberRecognizer_root           - directory containing the component.
#     NumberRecognizer_include        - directory containing the component includes.
#     COMPONENT_NAME to number-recognizer
#
# A component may be used either as a standalone project or as a part
# of other project.
#
macro(make_component_project component_name)
  capitalize_string(${component_name} project_name)
  if ("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
    # Standalone project
    message(STATUS "${project_name} is built as a standalone project")
    project("${project_name}")
    set(${project_name}_library_folder "library")
    set(${project_name}_test_folder "unit tests")
  else()
    # Part of another project
    message(STATUS "${project_name} is built as a subproject")
    if (NOT DEFINED EXTERNAL_LIBRARY_FOLDER)
      set(${project_name}_library_folder "External libraries")
    else()
      set(${project_name}_library_folder "${EXTERNAL_LIBRARY_FOLDER}")
    endif()
    if (NOT DEFINED EXTERNAL_LIBRARY_TEST_FOLDER)
      set(${project_name}_test_folder "External tests")
    else()
      set(${project_name}_test_folder "${EXTERNAL_LIBRARY_TEST_FOLDER}")
    endif()
  endif()

  set(${project_name}_root ${CMAKE_CURRENT_SOURCE_DIR})
  set(${project_name}_include ${CMAKE_CURRENT_SOURCE_DIR}/include)
  include_directories(${${project_name}_include})
  if(NOT WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11" )
  else()
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd")
  endif()
  set(COMPONENT_NAME "${component_name}")
endmacro(make_component_project)


# Creates target representing component unit tests
#
# Arguments:
#    list of unit tests source files
#
# Reads variables:
#    COMPONENT_NAME               - contains name of current component
#    NumberRecognizer_test_folder - IDE folder for unit tests
#
# Result: 
#    Creates executable for the unit tests, like "NumberRecognizerTests"
#    Creates target "check-number-recognizer" that runs the test
#
function(make_component_tests)
  capitalize_string(${COMPONENT_NAME} project_name)
  add_executable(${project_name}Tests
    test_runner.cpp
    ${ARGV}
  )
  set(outdir ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_CFG_INTDIR})
  set_output_directory(${project_name}Tests BINARY_DIR ${outdir} LIBRARY_DIR ${outdir})
  add_dependencies(${project_name}Tests ${project_name})
  set_target_properties(${project_name}Tests PROPERTIES FOLDER "${${project_name}_test_folder}")
  if(NOT Boost_INCLUDE_DIR)
    message(SEND_ERROR "Boost library was not located")
  endif()
  include_directories(${Boost_INCLUDE_DIR})
  target_link_libraries (${project_name}Tests ${project_name})
  target_link_libraries (${project_name}Tests ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY})

  set(${project_name}_test_location $<TARGET_FILE:${project_name}Tests>)
  add_custom_target(check-${COMPONENT_NAME}
    COMMAND ${${project_name}_test_location}
    DEPENDS ${project_name}Tests
  )
  set_target_properties(check-${COMPONENT_NAME} PROPERTIES FOLDER "${${project_name}_test_folder}")
endfunction(make_component_tests)


# Creates target representing component library
#
# Arguments:
#    TARGET  - this library may link with generated executable
#    HEADERS - following are additional include files (files in ./include
#              does not need to be mentioned here).
#    list of component source files
#
# Reads variables:
#    COMPONENT_NAME                  - contains name of current component
#    NumberRecognizer_library_folder - IDE folder for component libraries
#
# Result: 
#    Creates library "NumberRecognizer"
#
function(make_component_library)
  capitalize_string(${COMPONENT_NAME} project_name)
  set(srcs)

  cmake_parse_arguments(ARG
    "TARGET"
    ""
    "HEADERS"
    ${ARGN}
  )

  # Add header defined by this library
  if(MSVC_IDE OR XCODE)
    file(
      GLOB_RECURSE headers
      ${${project_name}_include}/*.h
      ${${project_name}_include}/*.def
    )
    set_source_files_properties(${headers} PROPERTIES HEADER_FILE_ONLY ON)
    if(headers OR ARG_HEADERS)
      set(srcs ${headers} ${ARG_HEADERS})
    endif()
  endif(MSVC_IDE OR XCODE)

  # Create library
  add_library(${project_name}
    ${srcs}
    ${ARG_UNPARSED_ARGUMENTS}
  )
  set_target_properties(${project_name} PROPERTIES FOLDER "${${project_name}_library_folder}")

  # If the library is marked as TARGET, copy this library file into the
  # directory where runtime libraries reside.
  if (ARG_TARGET AND COMPONENT_RTLIB_PATH)
    message(STATUS "Component ${project_name} provides runtime library")
    set_target_properties(
      ${project_name}
      PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${COMPONENT_RTLIB_PATH}
        ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${COMPONENT_RTLIB_PATH}
    )
  endif()
endfunction(make_component_library)


# Transforms component name from snake-case to CamelCase
#
# number-recognizer -> NumberRecognizer
#
function(capitalize_string str result_name)
  string(REGEX MATCHALL "([A-Za-z][A-Za-z0-9]*)" word_list ${str})
  set(result "")
  foreach (word ${word_list})
    string(SUBSTRING ${word} 0 1 FIRST_LETTER)
    string(TOUPPER ${FIRST_LETTER} FIRST_LETTER)
    string(REGEX REPLACE "^.(.*)" "${FIRST_LETTER}\\1" word "${word}")
    string(APPEND result ${word})
  endforeach()
  set(${result_name} ${result} PARENT_SCOPE)
endfunction(capitalize_string)
