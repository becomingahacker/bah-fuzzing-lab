add_fuzzer( bootp-fuzz-template
    SOURCES ../service_bootp.cc
    bootp-fuzz-template.cc
    service_plugin_mock.cc
    ${CMAKE_SOURCE_DIR}/src/sfip/sf_ip.cc
    ${CMAKE_SOURCE_DIR}/src/protocols/ip.cc
    ${CMAKE_SOURCE_DIR}/src/protocols/layer.cc
)
target_include_directories( bootp-fuzz-template PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/network_inspectors/appid
    ${CMAKE_SOURCE_DIR}/src/network_inspectors/appid/service_plugins
    ${CMAKE_SOURCE_DIR}/src/protocols/test
)

add_fuzzer( bootp-fuzz-template-answer
    SOURCES ../service_bootp.cc
    bootp-fuzz-template-answer.cc
    service_plugin_mock.cc
    ${CMAKE_SOURCE_DIR}/src/sfip/sf_ip.cc
    ${CMAKE_SOURCE_DIR}/src/protocols/ip.cc
    ${CMAKE_SOURCE_DIR}/src/protocols/layer.cc
)
target_include_directories( bootp-fuzz-template-answer PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/network_inspectors/appid
    ${CMAKE_SOURCE_DIR}/src/network_inspectors/appid/service_plugins
    ${CMAKE_SOURCE_DIR}/src/protocols/test
)