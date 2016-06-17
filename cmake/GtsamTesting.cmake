# This file defines the two macros below for easily adding groups of unit tests and scripts,
# as well as sets up unit testing and defines several cache options used to control how
# tests and scripts are built and run.



###############################################################################
# Macro:
#
# gtsamAddTestsGlob(groupName globPatterns excludedFiles linkLibraries)
# 
# Add a group of unit tests.  A list of unit test .cpp files or glob patterns specifies the
# tests to create.  Tests are assigned into a group name so they can easily by run
# independently with a make target.  Running 'make check' builds and runs all tests.
#
# Usage example:
#   gtsamAddTestsGlob(basic "test*.cpp" "testBroken.cpp" "gtsam;GeographicLib")
#
# Arguments:
#   groupName:     A name that will allow this group of tests to be run independently, e.g.
#                  'basic' causes a 'check.basic' target to be created to run this test
#                  group.
#   globPatterns:  The list of files or glob patterns from which to create unit tests, with
#                  one test created for each cpp file.  e.g. "test*.cpp", or
#                  "testA*.cpp;testB*.cpp;testOneThing.cpp".
#   excludedFiles: A list of files or globs to exclude, e.g. "testC*.cpp;testBroken.cpp".
#                  Pass an empty string "" if nothing needs to be excluded.
#   linkLibraries: The list of libraries to link to in addition to CppUnitLite.
macro(gtsamAddTestsGlob groupName globPatterns excludedFiles linkLibraries)
	gtsamAddTestsGlob_impl("${groupName}" "${globPatterns}" "${excludedFiles}" "${linkLibraries}")
endmacro()


###############################################################################
# Macro:
#
# gtsamAddExamplesGlob(globPatterns excludedFiles linkLibraries)
# 
# Add scripts that will serve as examples of how to use the library.  A list of files or
# glob patterns is specified, and one executable will be created for each matching .cpp
# file.  These executables will not be installed.  They are built with 'make all' if
# GTSAM_BUILD_EXAMPLES_ALWAYS is enabled.  They may also be built with 'make examples'.
#
# Usage example:
#   gtsamAddExamplesGlob("*.cpp" "BrokenExample.cpp" "gtsam;GeographicLib")
#
# Arguments:
#   globPatterns:  The list of files or glob patterns from which to create examples, with
#                  one program created for each cpp file.  e.g. "*.cpp", or
#                  "A*.cpp;B*.cpp;MyExample.cpp".
#   excludedFiles: A list of files or globs to exclude, e.g. "C*.cpp;BrokenExample.cpp".  Pass
#                  an empty string "" if nothing needs to be excluded.
#   linkLibraries: The list of libraries to link to.
macro(gtsamAddExamplesGlob globPatterns excludedFiles linkLibraries)
	gtsamAddExesGlob_impl("${globPatterns}" "${excludedFiles}" "${linkLibraries}" "examples" ${GTSAM_BUILD_EXAMPLES_ALWAYS})
endmacro()


###############################################################################
# Macro:
#
# gtsamAddTimingGlob(globPatterns excludedFiles linkLibraries)
# 
# Add scripts that time aspects of the library.  A list of files or
# glob patterns is specified, and one executable will be created for each matching .cpp
# file.  These executables will not be installed.  They are not built with 'make all',
# but they may be built with 'make timing'.
#
# Usage example:
#   gtsamAddTimingGlob("*.cpp" "DisabledTimingScript.cpp" "gtsam;GeographicLib")
#
# Arguments:
#   globPatterns:  The list of files or glob patterns from which to create programs, with
#                  one program created for each cpp file.  e.g. "*.cpp", or
#                  "A*.cpp;B*.cpp;MyExample.cpp".
#   excludedFiles: A list of files or globs to exclude, e.g. "C*.cpp;BrokenExample.cpp".  Pass
#                  an empty string "" if nothing needs to be excluded.
#   linkLibraries: The list of libraries to link to.
macro(gtsamAddTimingGlob globPatterns excludedFiles linkLibraries)
	gtsamAddExesGlob_impl("${globPatterns}" "${excludedFiles}" "${linkLibraries}" "timing" ${GTSAM_BUILD_TIMING_ALWAYS})
endmacro()


# Implementation follows:

# Build macros for using tests
enable_testing()

option(GTSAM_BUILD_TESTS                 "Enable/Disable building of tests"          ON)
option(GTSAM_BUILD_EXAMPLES_ALWAYS       "Build examples with 'make all' (build with 'make examples' if not)"       ON)
option(GTSAM_BUILD_TIMING_ALWAYS         "Build timing scripts with 'make all' (build with 'make timing' if not"    OFF)

# Add option for combining unit tests
if(MSVC OR XCODE_VERSION)
	option(GTSAM_SINGLE_TEST_EXE "Combine unit tests into single executable (faster compile)" ON)
else()
	option(GTSAM_SINGLE_TEST_EXE "Combine unit tests into single executable (faster compile)" OFF)
endif()
mark_as_advanced(GTSAM_SINGLE_TEST_EXE)
#Parallelize CTests since ctest supports the -j command
#Get number of cores from here: https://cmake.org/pipermail/cmake/2010-October/040122.html
if(NOT DEFINED PROCESSOR_COUNT)
	# Unknown:
	set(PROCESSOR_COUNT 0)

	# Linux:
	set(cpuinfo_file "/proc/cpuinfo")
	if(EXISTS "${cpuinfo_file}")
		file(STRINGS "${cpuinfo_file}" procs REGEX "^processor.: [0-9]+$")
		list(LENGTH procs PROCESSOR_COUNT)
	endif()

	# Mac:
	if(APPLE)
		find_program(cmd_sys_pro "system_profiler")
		if(cmd_sys_pro)
			execute_process(COMMAND ${cmd_sys_pro} OUTPUT_VARIABLE info)
			string(REGEX REPLACE "^.*Total Number Of Cores: ([0-9]+).*$" "\\1"
					PROCESSOR_COUNT "${info}")
		endif()
	endif()

	# Windows:
	if(WIN32)
		set(PROCESSOR_COUNT "$ENV{NUMBER_OF_PROCESSORS}")
	endif()
endif()

if(PROCESSOR_COUNT)
	set(CTEST_BUILD_FLAGS "-j${PROCESSOR_COUNT}")
endif()

# Enable make check (http://www.cmake.org/Wiki/CMakeEmulateMakeCheck)
if(GTSAM_BUILD_TESTS)
    add_custom_target(check COMMAND ${CMAKE_CTEST_COMMAND} ${CTEST_BUILD_FLAGS} -C $<CONFIGURATION> --output-on-failure)
endif()

# Add examples target
add_custom_target(examples)

# Add timing target
add_custom_target(timing)

# Add target to build tests without running
add_custom_target(all.tests)

# Implementations of this file's macros:

macro(gtsamAddTestsGlob_impl groupName globPatterns excludedFiles linkLibraries)
	if(GTSAM_BUILD_TESTS)
		# Add group target if it doesn't already exist
	    if(NOT TARGET check.${groupName})
			add_custom_target(check.${groupName} COMMAND ${CMAKE_CTEST_COMMAND} -C $<CONFIGURATION> --output-on-failure)
		endif()
	
	    # Get all script files
        file(GLOB script_files ${globPatterns})

	    # Remove excluded scripts from the list
	    if(NOT "${excludedFiles}" STREQUAL "")
			file(GLOB excludedFilePaths ${excludedFiles})
			if("${excludedFilePaths}" STREQUAL "")
				message(WARNING "The pattern '${excludedFiles}' for excluding tests from group ${groupName} did not match any files")
			else()
		    	list(REMOVE_ITEM script_files ${excludedFilePaths})
			endif()
	    endif()
	
		# Separate into source files and headers (allows for adding headers to show up in
		# MSVC and Xcode projects).
		set(script_srcs "")
		set(script_headers "")
		foreach(script_file IN ITEMS ${script_files})
			get_filename_component(script_ext ${script_file} EXT)
			if(script_ext MATCHES "(h|H)")
				list(APPEND script_headers ${script_file})
			else()
				list(APPEND script_srcs ${script_file})
			endif()
		endforeach()
	
		# Don't put test files in folders in MSVC and Xcode because they're already grouped
		source_group("" FILES ${script_srcs} ${script_headers})

		if(NOT GTSAM_SINGLE_TEST_EXE)
			# Default for Makefiles - each test in its own executable
			foreach(script_src IN ITEMS ${script_srcs})
				# Get test base name
				get_filename_component(script_name ${script_src} NAME_WE)
			
				# Add executable
				add_executable(${script_name} ${script_src} ${script_headers})
				target_link_libraries(${script_name} CppUnitLite ${linkLibraries})
				
				# Add target dependencies
				add_test(NAME ${script_name} COMMAND ${script_name})
				add_dependencies(check.${groupName} ${script_name})
				add_dependencies(check ${script_name})
                add_dependencies(all.tests ${script_name})
				if(NOT MSVC AND NOT XCODE_VERSION)
				  add_custom_target(${script_name}.run ${EXECUTABLE_OUTPUT_PATH}${script_name} DEPENDS ${script_name})
				endif()
			
				# Add TOPSRCDIR
				set_property(SOURCE ${script_src} APPEND PROPERTY COMPILE_DEFINITIONS "TOPSRCDIR=\"${PROJECT_SOURCE_DIR}\"")
			
				# Exclude from 'make all' and 'make install'
				set_target_properties(${script_name} PROPERTIES EXCLUDE_FROM_ALL ON)
			
				# Configure target folder (for MSVC and Xcode)
				set_property(TARGET ${script_name} PROPERTY FOLDER "Unit tests/${groupName}")
			endforeach()
		else()
			# Default on MSVC and XCode - combine test group into a single exectuable
			set(target_name check_${groupName}_program)
		
			# Add executable
			add_executable(${target_name} ${script_srcs} ${script_headers})
			target_link_libraries(${target_name} CppUnitLite ${linkLibraries})
		
			# Only have a main function in one script - use preprocessor
			set(rest_script_srcs ${script_srcs})
			list(REMOVE_AT rest_script_srcs 0)
			set_property(SOURCE ${rest_script_srcs} APPEND PROPERTY COMPILE_DEFINITIONS "main=inline no_main")
		
			# Add target dependencies
			add_test(NAME ${target_name} COMMAND ${target_name})
			add_dependencies(check.${groupName} ${target_name})
			add_dependencies(check ${target_name})
			if(NOT XCODE_VERSION)
				add_dependencies(all.tests ${script_name})
			endif()
		
			# Add TOPSRCDIR
			set_property(SOURCE ${script_srcs} APPEND PROPERTY COMPILE_DEFINITIONS "TOPSRCDIR=\"${PROJECT_SOURCE_DIR}\"")
		
			# Exclude from 'make all' and 'make install'
			set_target_properties(${target_name} PROPERTIES EXCLUDE_FROM_ALL ON)

			# Configure target folder (for MSVC and Xcode)
			set_property(TARGET ${script_name} PROPERTY FOLDER "Unit tests")
		endif()
	endif()
endmacro()


macro(gtsamAddExesGlob_impl globPatterns excludedFiles linkLibraries groupName buildWithAll)
    # Get all script files
    file(GLOB script_files ${globPatterns})

    # Remove excluded scripts from the list
    if(NOT "${excludedFiles}" STREQUAL "")
		file(GLOB excludedFilePaths ${excludedFiles})
		if("${excludedFilePaths}" STREQUAL "")
			message(WARNING "The script exclusion pattern '${excludedFiles}' did not match any files")
		else()
	    	list(REMOVE_ITEM script_files ${excludedFilePaths})
		endif()
    endif()

	# Separate into source files and headers (allows for adding headers to show up in
	# MSVC and Xcode projects).
	set(script_srcs "")
	set(script_headers "")
	foreach(script_file IN ITEMS ${script_files})
		get_filename_component(script_ext ${script_file} EXT)
		if(script_ext MATCHES "(h|H)")
			list(APPEND script_headers ${script_file})
		else()
			list(APPEND script_srcs ${script_file})
		endif()
	endforeach()

	# Don't put test files in folders in MSVC and Xcode because they're already grouped
	source_group("" FILES ${script_srcs} ${script_headers})

	# Create executables
	foreach(script_src IN ITEMS ${script_srcs})
		# Get script base name
		get_filename_component(script_name ${script_src} NAME_WE)

		# Add executable
		add_executable(${script_name} ${script_src} ${script_headers})
		target_link_libraries(${script_name} ${linkLibraries})
	
		# Add target dependencies
		add_dependencies(${groupName} ${script_name})
		if(NOT MSVC AND NOT XCODE_VERSION)
		  add_custom_target(${script_name}.run ${EXECUTABLE_OUTPUT_PATH}${script_name} DEPENDS ${script_name})
		endif()

		# Add TOPSRCDIR
		set_property(SOURCE ${script_src} APPEND PROPERTY COMPILE_DEFINITIONS "TOPSRCDIR=\"${PROJECT_SOURCE_DIR}\"")

        # Exclude from all or not - note weird variable assignment because we're in a macro	
	    set(buildWithAll_on ${buildWithAll})
		if(NOT buildWithAll_on)
			# Exclude from 'make all' and 'make install'
			set_target_properties("${script_name}" PROPERTIES EXCLUDE_FROM_ALL ON)
		endif()

		# Configure target folder (for MSVC and Xcode)
		set_property(TARGET ${script_name} PROPERTY FOLDER "${groupName}")
	endforeach()
endmacro()
