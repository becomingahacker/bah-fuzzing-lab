// new_service_plugin_mock.cc
//
// Workshop template: minimal stubs needed to link bootp-fuzz-template.
//
// Each function below is a symbol that service_bootp.cc or
// bootp-fuzz-template.cc references but that Snort proper would normally
// provide. The bodies are intentionally left empty (or return a trivial
// default) so the binary links. Participants: focus on sections [1] and [2]
// -- those are the ones whose behaviour your harness actually depends on.
// Sections [3]-[5] are linker glue you almost never need to touch.
//
// Sections:
//   [1] Stubs called directly from service_bootp.cc
//   [2] Stubs reached via the BootpServiceDetector vtable / base ctors
//   [3] Stubs the harness drags in by constructing Packet, AppIdSession,
//       AppIdInspector, AppIdModule, OdpContext, AppIdConfig
//   [4] Linker glue: empty bodies pulled in transitively by member-default-
//       construction of the section [3] objects (PatternMatchers, Discovery
//       vtables, ApplicationDescriptor, SearchTool, snort_strdup, ...).
//       Leave alone unless the linker complains.
//   [5] Cleanup helpers the harness calls between iterations

#include <cstdint>
#include <cstring>
#include <unordered_set>

#include "../../appid_inspector.h"
#include "../../appid_module.h"
#include "../../client_plugins/client_detector.h"
#include "../service_detector.h"
#include "detection/detection_engine.h"
#include "framework/data_bus.h"
#include "protocols/tcp.h"
#include "service_plugin_mock.h"

using namespace snort;

// ---------------------------------------------------------------------------
// [1] Stubs referenced directly from service_bootp.cc
// ---------------------------------------------------------------------------

// TODO: Called from BootpServiceDetector ctor:
//         handler->register_detector(name, this, proto)
//
// WORKSHOP STABILITY BUG ----------------------------------------------------
// This stub "remembers" every detector pointer it has ever seen and walks
// the whole set on each call -- mimicking a plausible mock that pretends to
// emulate Snort's real registration bookkeeping. Because the harness never
// clears g_registered_detectors between iterations, the set grows
// monotonically in persistent mode, and the loop body executes a different
// number of times every iteration. AFL records the per-edge hit counts as
// drifting values -> stability collapses.
//
// In per-input-fork mode (find-unstable-edges.sh) this bug is INVISIBLE
// because the static set is reinitialized every fresh process.
//
// Workshop fix: clear g_registered_detectors in cleanup_session_detector_data
// (or, more honestly, don't write stubs that accumulate state).
// ---------------------------------------------------------------------------
static std::unordered_set<const AppIdDetector*> g_registered_detectors;

void AppIdDiscovery::register_detector(const std::string&, AppIdDetector* d, IpProtocol)
{
    g_registered_detectors.insert(d);
    for (auto* prev : g_registered_detectors)
    {
        // A real branch the optimizer can't elide; the loop count itself
        // is the per-iteration coverage signal that destabilizes the run.
        if (prev == d)
            (void)prev;
    }
}

// TODO: Called on successful BOOTP/DHCP detection:
//         add_service(args.change_bits, args.asd, args.pkt, args.dir, APP_ID_DHCP)
int ServiceDetector::add_service(AppidChangeBits&, AppIdSession&, const snort::Packet*,
    AppidSessionDirection, AppId, const char*, const char*, AppIdServiceSubtype*)
{
    return 0;
}

// TODO: Called by service_bootp.cc when more data is needed (`goto inprocess`).
int ServiceDetector::service_inprocess(AppIdSession&, const snort::Packet*, AppidSessionDirection)
{
    return 0;
}

// TODO: Called by service_bootp.cc when validation fails (`goto fail`).
int ServiceDetector::fail_service(AppIdSession&, const snort::Packet*, AppidSessionDirection)
{
    return 0;
}

// TODO: Called by service_bootp.cc when payload is wrong protocol (`goto not_compatible`).
int ServiceDetector::incompatible_data(AppIdSession&, const snort::Packet*, AppidSessionDirection)
{
    return 0;
}

// TODO: BootpServiceDetector::add_dhcp_info / add_new_dhcp_lease ask the engine
//       for the current packet so they can attach it to a published event.
//       Returning a real Packet* (not nullptr) is required because the callers
//       dereference p->flow.
snort::Packet* snort::DetectionEngine::get_current_packet()
{
    static Packet p;
    p.flow = reinterpret_cast<Flow*>(1);
    return &p;
}

// TODO: BootpServiceDetector publishes DHCP_DATA / DHCP_INFO events on success.
void snort::DataBus::publish(unsigned, unsigned, snort::DataEvent&, snort::Flow*)
{
}

// TODO: Used as the publisher id when bootp emits DHCP events.
unsigned AppIdInspector::get_pub_id()
{
    return 0;
}

// ---------------------------------------------------------------------------
// [2] Stubs reached via BootpServiceDetector's base-class subobjects
//     (ServiceDetector ctor, vtable slot for register_appid)
// ---------------------------------------------------------------------------

// TODO: Base ctor invoked implicitly by BootpServiceDetector ctor.
ServiceDetector::ServiceDetector()
{
}

// TODO: Pure virtual on AppIdDetector, defined on ServiceDetector. Lives in
//       the BootpServiceDetector vtable even though service_bootp.cc never
//       calls it directly.
void ServiceDetector::register_appid(AppId, unsigned, OdpContext&)
{
}

// ---------------------------------------------------------------------------
// [3] Harness-side stubs: pulled in by the objects bootp-fuzz-template.cc
//     constructs (Packet, AppIdSession, AppIdInspector, AppIdModule,
//     OdpContext, AppIdConfig). Most of these can stay empty.
// ---------------------------------------------------------------------------

// snort::Packet
namespace snort
{
Packet::Packet(bool)
{
    // TODO: ptrs.tcph must point at a valid TCPHdr because some codepaths
    //       deref it unconditionally. The minimum needed for bootp is below;
    //       extend if your harness exercises TCP fields.
    ptrs.reset();
    static snort::tcp::TCPHdr tcph = { };
    ptrs.tcph = &tcph;
}
Packet::~Packet() = default;
}  // namespace snort

// snort::Inspector base of AppIdInspector
namespace snort
{
Inspector::Inspector() = default;
Inspector::~Inspector() = default;
bool Inspector::likes(Packet*) { return true; }
bool Inspector::get_buf(const char*, Packet*, InspectionBuffer&) { return true; }
class snort::StreamSplitter* Inspector::get_splitter(bool) { return nullptr; }
}  // namespace snort

// snort::Module base of AppIdModule
snort::Module::Module(const char*, const char*) { }
void snort::Module::sum_stats(bool) { }
void snort::Module::show_interval_stats(std::vector<unsigned>&, FILE*) { }
void snort::Module::show_stats() { }
void snort::Module::init_stats(bool) { }
void snort::Module::reset_stats() { }
void snort::Module::main_accumulate_stats() { }
PegCount snort::Module::get_global_count(const char*) const { return 0; }

// snort::FlowData base of AppIdSession
namespace snort
{
FlowData::FlowData(unsigned) { }
FlowData::FlowData(unsigned, const char*) { }
FlowData::~FlowData() = default;
}  // namespace snort

// AppIdConfig / AppIdContext / OdpContext globals
AppIdConfig stub_config;
AppIdContext stub_ctxt(stub_config);
static OdpContext stub_odp_ctxt(stub_config, nullptr);
OdpContext* AppIdContext::odp_ctxt = &stub_odp_ctxt;
AppIdConfig::~AppIdConfig() = default;
OdpContext::OdpContext(const AppIdConfig&, snort::SnortConfig*) { }

// AppIdModule
AppIdModule::AppIdModule() : snort::Module("appid_fuzz", "appid fuzz stubs") { }
AppIdModule::~AppIdModule() = default;
bool AppIdModule::begin(const char*, int, snort::SnortConfig*) { return false; }
bool AppIdModule::set(const char*, snort::Value&, snort::SnortConfig*) { return false; }
bool AppIdModule::end(const char*, int, snort::SnortConfig*) { return false; }
const snort::Command* AppIdModule::get_commands() const { return nullptr; }
const PegInfo* AppIdModule::get_pegs() const { return nullptr; }
PegCount* AppIdModule::get_counts() const { return nullptr; }
void AppIdModule::set_trace(const snort::Trace*) const { }
const snort::TraceOption* AppIdModule::get_trace_options() const { return nullptr; }
snort::ProfileStats* AppIdModule::get_profile(unsigned, const char*&, const char*&) const
{ return nullptr; }
void AppIdModule::sum_stats(bool) { }
void AppIdModule::reset_stats() { }
void AppIdModule::show_dynamic_stats() { }

// AppIdInspector
static AppIdConfig g_cfg;
AppIdInspector::AppIdInspector(AppIdModule& m) : snort::Inspector(), ctxt(g_cfg) { (void)m; }
AppIdInspector::~AppIdInspector() = default;
bool AppIdInspector::configure(snort::SnortConfig*) { return true; }
void AppIdInspector::show(const snort::SnortConfig*) const { }
void AppIdInspector::tinit() { }
void AppIdInspector::tterm() { }
void AppIdInspector::tear_down(snort::SnortConfig*, bool) { }
void AppIdInspector::eval(snort::Packet*) { }

// AppIdSessionApi
snort::AppIdSessionApi::AppIdSessionApi(const AppIdSession*, const SfIp&) { }
void snort::AppIdSessionApi::set_netbios_name(AppidChangeBits&, const char*) { }

// AppIdSession
unsigned AppIdSession::inspector_id = 0;
AppIdSession::AppIdSession(IpProtocol proto, const snort::SfIp* ip, uint16_t,
    AppIdInspector& inspector, OdpContext& odpctxt, uint32_t
#ifndef DISABLE_TENANT_ID
    , uint32_t
#endif
    ) : snort::FlowData(inspector_id, nullptr),
        inspector(inspector), config(stub_config),
        api(*(new snort::AppIdSessionApi(this, *ip))), odp_ctxt(odpctxt)
{
    protocol = proto;
}
AppIdSession::~AppIdSession()
{
    if (tsession)
    {
        delete tsession;
        tsession = nullptr;
    }
    delete &api;
}
void AppIdSession::free_flow_data() { }
AppIdFlowData* AppIdSession::get_flow_data(unsigned) const { return nullptr; }
int AppIdSession::add_flow_data_id(uint16_t, ServiceDetector*) { return 0; }

// AppIdDetector — referenced via BootpServiceDetector's vtable / inherited API.
int AppIdDetector::initialize(AppIdInspector&) { return 0; }
int AppIdDetector::data_add(AppIdSession&, AppIdFlowData*) { return 0; }
AppIdFlowData* AppIdDetector::data_get(const AppIdSession&) { return nullptr; }
void AppIdDetector::add_user(AppIdSession&, const char*, AppId, bool, AppidChangeBits&) { }
void AppIdDetector::add_payload(AppIdSession&, AppId) { }
void AppIdDetector::add_app(const snort::Packet&, AppIdSession&, AppidSessionDirection,
    AppId, AppId, const char*, AppidChangeBits&) { }

// AppIdDebug + logging globals — referenced by macros in appid headers.
THREAD_LOCAL AppIdDebug* appidDebug = nullptr;
THREAD_LOCAL bool appid_trace_enabled = false;
void AppIdDebug::activate(const snort::Flow*, const AppIdSession*, bool) { active = false; }
void appid_log(const snort::Packet*, unsigned char, const char*, ...) { }
void appid_log(const void*, const uint8_t, const char*, va_list) { }
THREAD_LOCAL AppIdStats appid_stats;

// ---------------------------------------------------------------------------
// [4] Linker glue. These are pulled in transitively by member-default-
//     construction of the section [3] objects:
//       * OdpContext owns *PatternMatchers, ServiceDiscovery, ClientDiscovery,
//         ApplicationDescriptor subobjects -- all of which need ctors/dtors
//         and SearchTool ctor/dtor for THEIR members.
//       * AppIdContext owns DiscoveryFilter.
//       * sf_ip.cc (linked separately) calls snort::snort_strdup.
//     You will not normally need to touch these in the workshop.
// ---------------------------------------------------------------------------

// snort::SearchTool — pulled in by *PatternMatchers and OdpContext members.
namespace snort
{
SearchTool::SearchTool(bool, const char*) { }
SearchTool::~SearchTool() = default;
}  // namespace snort

// String utilities used by sf_ip.cc.
namespace snort
{
char* snort_strdup(const char* str)
{
    assert(str);
    size_t n = strlen(str) + 1;
    char* p = static_cast<char*>(snort_alloc(n));
    memcpy(p, str, n);
    return p;
}

char* snort_strndup(const char* src, size_t dst_size)
{
    char* dst = new char[dst_size + 1];
    memset(dst, 0, dst_size + 1);
    return strncpy(dst, src, dst_size);
}
}  // namespace snort

// AppIdDiscovery / ServiceDiscovery / ClientDiscovery
// Each needs at least one out-of-line virtual to anchor its vtable.
AppIdDiscovery::~AppIdDiscovery() { }
void AppIdDiscovery::register_tcp_pattern(AppIdDetector*, const uint8_t* const, unsigned, int, unsigned) { }
void AppIdDiscovery::register_udp_pattern(AppIdDetector*, const uint8_t* const, unsigned, int, unsigned) { }
void AppIdDiscovery::add_pattern_data(AppIdDetector*, snort::SearchTool&, int,
    const uint8_t* const, unsigned, unsigned) { }
int AppIdDiscovery::add_service_port(AppIdDetector*, const ServiceDetectorPort&) { return 0; }

void ServiceDiscovery::initialize(AppIdInspector&) { }
void ServiceDiscovery::reload() { }
int ServiceDiscovery::add_service_port(AppIdDetector*, const ServiceDetectorPort&) { return 0; }

void ClientDiscovery::initialize(AppIdInspector&) { }
void ClientDiscovery::reload() { }
ClientDetector::ClientDetector() { }
void ClientDetector::register_appid(int, unsigned int, OdpContext&) { }

// DiscoveryFilter — member of AppIdContext / AppIdInspector.
DiscoveryFilter::~DiscoveryFilter() { }

// *PatternMatchers — members of OdpContext.
AlpnPatternMatchers::~AlpnPatternMatchers() { }
EveCaPatternMatchers::~EveCaPatternMatchers() { }
HostPatternMatchers::~HostPatternMatchers() { }
SipPatternMatchers::~SipPatternMatchers() { }
HttpPatternMatchers::~HttpPatternMatchers() { }
DnsPatternMatchers::~DnsPatternMatchers() { }
CipPatternMatchers::~CipPatternMatchers() { }
UserDataMap::~UserDataMap() { }

// ApplicationDescriptor + derived classes own a vtable that references both
// virtual set_id overloads; defining them out-of-line emits the vtable
// (and the typeinfo) here.
void ApplicationDescriptor::set_id(AppId) { }
void ApplicationDescriptor::set_id(const snort::Packet&, AppIdSession&,
    AppidSessionDirection, AppId, AppidChangeBits&) { }
void ServiceAppDescriptor::set_id(AppId, OdpContext&) { }
void ClientAppDescriptor::update_user(AppId, const char*, AppidChangeBits&) { }

// Other AppId surface that headers reference but bootp doesn't use.
void show_stats(PegCount*, const PegInfo*, unsigned, const char*) { }
AppIdConfig config;
AppIdContext ctxt(config);

// app_info_table.cc
AppInfoTableEntry* AppInfoManager::get_app_info_entry(int) { return nullptr; }
bool AppInfoManager::configured() { return true; }

// ---------------------------------------------------------------------------
// [5] Cleanup helpers explicitly invoked by bootp-fuzz-template.cc.
//     These run after every fuzz iteration; if they leak, ASan will fire
//     false-positive reports.
// ---------------------------------------------------------------------------

// TODO: Free any per-session detector blob your harness installs via
//       AppIdDetector::data_add.
void cleanup_session_detector_data(const AppIdSession*)
{
}

// TODO: Drop everything stashed in your data_add map and any future-session
//       caches. For bootp-only this can be a no-op.
void clear_appid_detector_data()
{
}
