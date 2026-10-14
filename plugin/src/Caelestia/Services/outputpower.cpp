#include "outputpower.hpp"
#include "wlr-output-power-management-unstable-v1-client.h"
#include <qfuturewatcher.h>
#include <qelapsedtimer.h>
#include <qtconcurrentrun.h>
#include <wayland-client.h>
#include <algorithm>
#include <cstring>
#include <vector>
#include <poll.h>

namespace caelestia::services {
namespace {
struct Connection {
    zwlr_output_power_manager_v1* manager = nullptr;
    std::vector<wl_output*> outputs;
    bool failed = false;
};
// Bound every roundtrip: a disconnected or unresponsive compositor cannot
// strand a thread (or prevent application shutdown).
bool sync(wl_display* display) {
    bool done = false;
    auto* callback = wl_display_sync(display);
    static const wl_callback_listener listener = {
        [](void* data, wl_callback*, uint32_t) { *static_cast<bool*>(data) = true; }
    };
    wl_callback_add_listener(callback, &listener, &done);
    QElapsedTimer deadline;
    deadline.start();
    while (!done && deadline.elapsed() < 2000) {
        while (wl_display_prepare_read(display) != 0) {
            if (wl_display_dispatch_pending(display) < 0) { wl_callback_destroy(callback); return false; }
        }
        wl_display_flush(display);
        pollfd fd{wl_display_get_fd(display), POLLIN, 0};
        if (poll(&fd, 1, static_cast<int>(2000 - deadline.elapsed())) <= 0) {
            wl_display_cancel_read(display); wl_callback_destroy(callback); return false;
        }
        if (wl_display_read_events(display) < 0 || wl_display_dispatch_pending(display) < 0) {
            wl_callback_destroy(callback); return false;
        }
    }
    wl_callback_destroy(callback);
    return done;
}
QString setPower(bool enabled) {
    auto* display = wl_display_connect(nullptr);
    if (!display) return QStringLiteral("Cannot connect to Wayland for display power control");
    Connection state;
    auto* registry = wl_display_get_registry(display);
    static const wl_registry_listener registryListener = {
        [](void* data, wl_registry* registryObject, uint32_t name, const char* interface, uint32_t) {
            auto& connection = *static_cast<Connection*>(data);
            if (std::strcmp(interface, "zwlr_output_power_manager_v1") == 0)
                connection.manager = static_cast<zwlr_output_power_manager_v1*>(wl_registry_bind(registryObject, name, &zwlr_output_power_manager_v1_interface, 1));
            else if (std::strcmp(interface, "wl_output") == 0)
                connection.outputs.push_back(static_cast<wl_output*>(wl_registry_bind(registryObject, name, &wl_output_interface, 1)));
        },
        [](void*, wl_registry*, uint32_t) {}
    };
    wl_registry_add_listener(registry, &registryListener, &state);
    QString error;
    std::vector<zwlr_output_power_v1*> powers;
    if (!sync(display) || !state.manager) {
        error = QStringLiteral("Compositor does not provide output power management");
    } else {
        static const zwlr_output_power_v1_listener powerListener = {
            [](void*, zwlr_output_power_v1*, uint32_t) {},
            [](void* data, zwlr_output_power_v1*) { static_cast<Connection*>(data)->failed = true; }
        };
        for (auto* output : state.outputs) {
            auto* power = zwlr_output_power_manager_v1_get_output_power(state.manager, output);
            zwlr_output_power_v1_add_listener(power, &powerListener, &state);
            powers.push_back(power);
            zwlr_output_power_v1_set_mode(power, enabled ? ZWLR_OUTPUT_POWER_V1_MODE_ON : ZWLR_OUTPUT_POWER_V1_MODE_OFF);
        }
        if (!sync(display) || state.failed) error = QStringLiteral("Display power request failed");
    }
    for (auto* power : powers) zwlr_output_power_v1_destroy(power);
    for (auto* output : state.outputs) wl_output_destroy(output);
    if (state.manager) zwlr_output_power_manager_v1_destroy(state.manager);
    wl_registry_destroy(registry);
    wl_display_flush(display);
    wl_display_disconnect(display);
    return error;
}
}
void OutputPower::setEnabled(bool enabled) {
    auto* watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher] {
        const auto error = watcher->result();
        if (!error.isEmpty()) { qWarning() << error; emit failed(error); }
        watcher->deleteLater();
    });
    // Sequential requests preserve off/on order across fast idle transitions.
    static QThreadPool pool;
    pool.setMaxThreadCount(1);
    watcher->setFuture(QtConcurrent::run(&pool, [enabled] { return setPower(enabled); }));
}
}
