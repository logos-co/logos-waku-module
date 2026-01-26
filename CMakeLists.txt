cmake_minimum_required(VERSION 3.14)
project(WakuModulePlugin LANGUAGES CXX)

include($ENV{LOGOS_MODULE_BUILDER_ROOT}/cmake/LogosModule.cmake)

logos_module(
    NAME waku_module
    SOURCES 
        src/waku_module_interface.h
        src/waku_module_plugin.h
        src/waku_module_plugin.cpp
    EXTERNAL_LIBS
        libwaku
)
