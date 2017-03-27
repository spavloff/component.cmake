cmake_minimum_required(VERSION 3.4)
include(CMakeParseArguments)

# Prepares build environment for using the specified component.
#
# Arguments:
#    component_name - a component name like "number-recognizer"
#
# Reads variables:
#    COMPONENT_LIBRARY_FOLDER - contains name of a folder in IDE, which
#                               will contain component libraries projects.
#    COMPONENT_TEST_FOLDER    - contains name of a folder in IDE, which
#                               will contain component unit test projects.
#    COMPONENT_LIBRARY_DIR    - the directory where components reside.
#
# If any of these variables is not test, it will be initialized.
#
# Result: 
#   Sets variables (for a component "number-recognizer"):
#     NumberRecognizer_library_folder - IDE folder for the component sources.
#     NumberRecognizer_test_folder    - IDE folder for the component unit tests.
#     NumberRecognizer_root           - directory containing the component.
#     NumberRecognizer_include        - list containing include directories of the component.
#     CURRENT_COMPONENT_NAME          - to the component name (number-recognizer)
#
#   Sets global variables, if they are not defined yet:
#     COMPONENT_LIBRARY_FOLDER
#     COMPONENT_TEST_FOLDER
#     COMPONENT_LIBRARY_DIR
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

    if (NOT DEFINED COMPONENT_LIBRARY_FOLDER)
      set(COMPONENT_LIBRARY_FOLDER "Component libraries"
          CACHE STRING "Folder for component libraries")
    endif()
    set(${project_name}_library_folder "${COMPONENT_LIBRARY_FOLDER}")

    if (NOT DEFINED COMPONENT_TEST_FOLDER)
      set(COMPONENT_TEST_FOLDER "Component unit tests"
          CACHE STRING "Folder for component unit tests")
    endif()
    set(${project_name}_test_folder "${COMPONENT_TEST_FOLDER}")

    get_filename_component(parent_dir "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
    if (NOT DEFINED COMPONENT_LIBRARY_DIR)
      set(COMPONENT_LIBRARY_DIR "${parent_dir}"
          CACHE PATH "Directory where components reside")
    else()
      if (${COMPONENT_LIBRARY_DIR} STREQUAL ${parent_dir})
      else()
        message(SEND_ERROR "Unexpected component location: ${parent_dir}, but components must be placed in ${COMPONENT_LIBRARY_DIR}")
      endif()
    endif()
  endif()

  set(${project_name}_root ${CMAKE_CURRENT_SOURCE_DIR})
  set(${project_name}_include ${${project_name}_root}/include)

  include_directories(${${project_name}_include})
  if(NOT WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14")
  else()
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd")
  endif()

  set(CURRENT_COMPONENT_NAME "${component_name}")
endmacro(make_component_project)


# Creates target representing component library.
#
# Arguments:
#    TARGET  - this library may link with generated executable.
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
function(make_component_library name)
  if (NOT CURRENT_COMPONENT_NAME)
    message(SEND_ERROR "Undefined component ${name}")
  endif()

  if (${name} STREQUAL ${CURRENT_COMPONENT_NAME})
  else()
    message(SEND_ERROR "Unexpected component name: ${name}, expected: ${CURRENT_COMPONENT_NAME}")
  endif()

  capitalize_string(${name} project_name)
  set(srcs)

  set(extra_arguments ${ARGV})
  list(REMOVE_AT extra_arguments 0)

  cmake_parse_arguments(
    ARG
    "TARGET"
    ""
    "HEADERS"
    ${extra_arguments}
  )

  # Add header defined by this library
  if(MSVC_IDE OR XCODE)
    file(
      GLOB_RECURSE headers
      # TODO: ${project_name}_include may be a list
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


# Creates target representing component unit tests.
#
# Arguments:
#    list of unit tests source files
#
# Reads variables:
#    CURRENT_COMPONENT_NAME    - contains name of current component
#    ${compoment}_test_folder  - IDE folder for unit tests
#
# Result:
#    Creates executable for the unit tests, like "NumberRecognizerTests"
#    Creates target "check-number-recognizer" that runs the test
#
function(make_component_tests name)
  if (NOT CURRENT_COMPONENT_NAME)
    message(SEND_ERROR "Undefined component")
  endif()

  if (${name} STREQUAL ${CURRENT_COMPONENT_NAME})
  else()
    message(SEND_ERROR "Unexpected component name: ${name}, expected: ${CURRENT_COMPONENT_NAME}")
  endif()

  set(extra_arguments ${ARGV})
  list(REMOVE_AT extra_arguments 0)

  capitalize_string(${CURRENT_COMPONENT_NAME} project_name)
  add_executable(${project_name}Tests
    test_runner.cpp
    ${extra_arguments}
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
  add_custom_target(check-${CURRENT_COMPONENT_NAME}
    COMMAND ${${project_name}_test_location}
    DEPENDS ${project_name}Tests
  )
  set_target_properties(check-${CURRENT_COMPONENT_NAME} PROPERTIES FOLDER "${${project_name}_test_folder}")
endfunction(make_component_tests)


macro(make_test_application name)
  set(options SHARED)
  set(oneValueArgs "")
  set(multiValueArgs CLANG CFLAGS SOURCES HEADERS)
  set(extra_arguments ${ARGV})
  list(REMOVE_AT extra_arguments 0)
  cmake_parse_arguments(
    ARG
    "${options}" "${oneValueArgs}" "${multiValueArgs}"
    ${extra_arguments}
  )
  set(object_list "")
  if (MSVC)
    set(CLANG_FLAGS --driver-mode=cl /EHsc /MTd)
  else()
    set(CLANG_FLAGS "-std=c++14") #TODO: remove particular standard
  endif()

  foreach(file ${ARG_CLANG})
    set(obj_file ${CMAKE_CURRENT_BINARY_DIR}/${file}.obj)
    set(src_file ${CMAKE_CURRENT_SOURCE_DIR}/${file})
    add_custom_command(
      OUTPUT ${obj_file}
      COMMAND clang ${CLANG_FLAGS} -c ${ARG_CFLAGS} -o ${obj_file} ${src_file}
      MAIN_DEPENDENCY ${src_file}
      DEPENDS ${src_file} clang Blick
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      COMMENT "Compiling ${src_file}"
    )
    set_source_files_properties(
      ${obj_file}
      PROPERTIES
        GENERATED TRUE
        EXTERNAL_OBJECT TRUE
    )
    list(APPEND object_list "${obj_file}")
  endforeach()

  set_source_files_properties(${ARG_HEADERS} PROPERTIES HEADER_FILE_ONLY ON)
  set_source_files_properties(${ARG_CLANG} PROPERTIES HEADER_FILE_ONLY ON)
  add_executable(${name}
    ${ARG_CLANG}
    ${ARG_SOURCES}
    ${ARG_HEADERS}
    ${ARG_UNPARSED_ARGUMENTS}
    ${object_list}
  )
  set(outdir ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_CFG_INTDIR})
  set_output_directory(${name} BINARY_DIR ${outdir} LIBRARY_DIR ${outdir})
  add_dependencies(${name} Blick clang)
  target_link_libraries (${name} Blick)
  if(MSVC)
    set_property(TARGET ${name} APPEND PROPERTY LINK_FLAGS /INCREMENTAL:NO)
  endif()
  set_target_properties(${name} PROPERTIES FOLDER "Component test applications")
endmacro(make_test_application)


# The following function is borrowed from LLVM sources (file llvm/cmake/modules/AddLLVM.cmake)
# If we are building a component inside LLVM source tree, use original implementation.
#
if (NOT LLVM_VERSION_MAJOR)
	# Set each output directory according to ${CMAKE_CONFIGURATION_TYPES}.
	# Note: Don't set variables CMAKE_*_OUTPUT_DIRECTORY any more,
	# or a certain builder, for eaxample, msbuild.exe, would be confused.
	function(set_output_directory target)
	  cmake_parse_arguments(ARG "" "BINARY_DIR;LIBRARY_DIR" "" ${ARGN})

	  # module_dir -- corresponding to LIBRARY_OUTPUT_DIRECTORY.
	  # It affects output of add_library(MODULE).
	  if(WIN32 OR CYGWIN)
		# DLL platform
		set(module_dir ${ARG_BINARY_DIR})
	  else()
		set(module_dir ${ARG_LIBRARY_DIR})
	  endif()
	  if(NOT "${CMAKE_CFG_INTDIR}" STREQUAL ".")
		foreach(build_mode ${CMAKE_CONFIGURATION_TYPES})
		  string(TOUPPER "${build_mode}" CONFIG_SUFFIX)
		  if(ARG_BINARY_DIR)
			string(REPLACE ${CMAKE_CFG_INTDIR} ${build_mode} bi ${ARG_BINARY_DIR})
			set_target_properties(${target} PROPERTIES "RUNTIME_OUTPUT_DIRECTORY_${CONFIG_SUFFIX}" ${bi})
		  endif()
		  if(ARG_LIBRARY_DIR)
			string(REPLACE ${CMAKE_CFG_INTDIR} ${build_mode} li ${ARG_LIBRARY_DIR})
			set_target_properties(${target} PROPERTIES "ARCHIVE_OUTPUT_DIRECTORY_${CONFIG_SUFFIX}" ${li})
		  endif()
		  if(module_dir)
			string(REPLACE ${CMAKE_CFG_INTDIR} ${build_mode} mi ${module_dir})
			set_target_properties(${target} PROPERTIES "LIBRARY_OUTPUT_DIRECTORY_${CONFIG_SUFFIX}" ${mi})
		  endif()
		endforeach()
	  else()
		if(ARG_BINARY_DIR)
		  set_target_properties(${target} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${ARG_BINARY_DIR})
		endif()
		if(ARG_LIBRARY_DIR)
		  set_target_properties(${target} PROPERTIES ARCHIVE_OUTPUT_DIRECTORY ${ARG_LIBRARY_DIR})
		endif()
		if(module_dir)
		  set_target_properties(${target} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${module_dir})
		endif()
	  endif()
	endfunction()
endif()


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
