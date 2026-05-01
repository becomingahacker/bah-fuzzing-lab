

#include "service_bootp.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <vector>

#include "fuzzer/FuzzedDataProvider.h"
#include "service_plugin_mock.h"
#include "../../appid_detector.h"
#include "../service_detector.h"
#include "../../appid_module.h"
#include "../../appid_inspector.h"
#include "../../../sfip/sf_ip.h"
#include "../../../protocols/tcp.h"

using namespace snort;
struct MatchedPatterns;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* Data, size_t Size)
{
    FuzzedDataProvider fuzzed_data(Data, Size);

    AppIdConfig cfg;
    OdpContext odp{ cfg, nullptr };
    AppIdModule module;
    AppIdInspector inspector{ module };
    snort::Packet pkt{ true };
    snort::SfIp src_ip;
    snort::SfIp dst_ip;

    // CHANGE ME ------------------------------------------------------------
    uint32_t src_addr = 0;
    uint32_t dst_addr = 0;
    // --------------------------------------------------------------

    src_ip.set(&src_addr, AF_INET);
    dst_ip.set(&dst_addr, AF_INET);
    pkt.ptrs.ip_api.set(src_ip, dst_ip);

    // CHANGE ME ------------------------------------------------------------
    pkt.ptrs.sp = 67;
    pkt.ptrs.dp = 67;
    // --------------------------------------------------------------

    ServiceDiscovery sd;
    BootpServiceDetector* detector = new BootpServiceDetector(&sd);

#ifdef DISABLE_TENANT_ID
    AppIdSession* session = new AppIdSession(IpProtocol::UDP, &src_ip,
        pkt.ptrs.sp, inspector, odp, 0);
#else
    AppIdSession* session = new AppIdSession(IpProtocol::UDP, &src_ip,
        pkt.ptrs.sp, inspector, odp, 0, 0);
#endif

    // CHANGE ME ------------------------------------------------------------
    AppidSessionDirection dir = fuzzed_data.ConsumeBool()
        ? APP_ID_FROM_RESPONDER : APP_ID_FROM_INITIATOR;
    // --------------------------------------------------------------

    // CHANGE ME ------------------------------------------------------------
    std::vector<uint8_t> payload = fuzzed_data.ConsumeRemainingBytes<uint8_t>();
    // --------------------------------------------------------------

    if (!payload.empty())
    {
        pkt.data = payload.data();
        // CHANGE ME ------------------------------------------------------------ 
        pkt.dsize = static_cast<uint16_t>(
            std::min<size_t>(payload.size(), UINT16_MAX));
        // --------------------------------------------------------------

        AppidChangeBits change_bits;
        AppIdDiscoveryArgs args(pkt.data, pkt.dsize, dir, *session,
            &pkt, change_bits);
        detector->validate(args);
    }

    // ---- Cleanup ---------------------------------------------------------
    cleanup_session_detector_data(session);
    delete session;
    delete detector; 
    clear_appid_detector_data(); // template is missing this delete, keeping state
    return 0;
}
