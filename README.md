# Component host

This is a CMake script that helps organizing components in a software project.

A component in this context is a project developed independently, that is used
in another project in the form of source files. The script allows configuring
the used components in a uniform manner, as a part of host project configuration.
Various parts of the component (libraies, headers, tests etc) are added to the
corresponding sets of the host project and become available for use.

A project that uses components must have a directory where the components are
placed, probably as git submodules. This script resides in a directory
`component.cmake` inside this directory:

    ...
        <directory-for-components>
            component.cmake
                main.cmake
            <component1-directory>
                include/
                src/
                unittests/
                CMakeLists.txt
            <component2-directory>


`CMakeLists.txt` of a component includes `main.cmake`, then it can make calls
to functions like `make_component_tests`, `make_component_library` etc to
configure the component. These functions configure a component as standalone
project or as a part of another.
