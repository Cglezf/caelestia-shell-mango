#include "nativecapture.hpp"
#include "ext-foreign-toplevel-list-v1-client.h"
#include "ext-image-capture-source-v1-client.h"
#include "ext-image-copy-capture-v1-client.h"
#include <wayland-client.h>
#include <qelapsedtimer.h>
#include <qtransform.h>
#include <poll.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cstring>
#include <vector>
#include <limits>

namespace caelestia::images {
namespace {
struct Capture {
    wl_display* display = nullptr;
    wl_registry* registry = nullptr;
    wl_shm* shm = nullptr;
    ext_foreign_toplevel_list_v1* list = nullptr;
    ext_foreign_toplevel_image_capture_source_manager_v1* sources = nullptr;
    ext_image_copy_capture_manager_v1* manager = nullptr;
    ext_foreign_toplevel_handle_v1* target = nullptr;
    ext_image_capture_source_v1* source = nullptr;
    ext_image_copy_capture_session_v1* session = nullptr;
    ext_image_copy_capture_frame_v1* frame = nullptr;
    wl_buffer* buffer = nullptr;
    std::vector<ext_foreign_toplevel_handle_v1*> handles;
    QString identifier;
    uint32_t width = 0, height = 0, format = WL_SHM_FORMAT_XRGB8888, transform = 0;
    bool haveFormat = false, done = false, constraintsReady = false, failed = false;
    void* memory = MAP_FAILED;
    size_t size = 0;
    ~Capture() {
        if (frame) ext_image_copy_capture_frame_v1_destroy(frame);
        if (session) ext_image_copy_capture_session_v1_destroy(session);
        if (source) ext_image_capture_source_v1_destroy(source);
        if (buffer) wl_buffer_destroy(buffer);
        if (memory != MAP_FAILED) munmap(memory, size);
        for (auto* handle : handles) ext_foreign_toplevel_handle_v1_destroy(handle);
        if (list) ext_foreign_toplevel_list_v1_destroy(list);
        if (sources) ext_foreign_toplevel_image_capture_source_manager_v1_destroy(sources);
        if (manager) ext_image_copy_capture_manager_v1_destroy(manager);
        if (shm) wl_shm_destroy(shm);
        if (registry) wl_registry_destroy(registry);
        if (display) { wl_display_flush(display); wl_display_disconnect(display); }
    }
};
bool awaitEvents(Capture& capture, bool constraints = false) {
    QElapsedTimer deadline;
    deadline.start();
    while (!(constraints ? capture.constraintsReady : capture.done) && !capture.failed && deadline.elapsed() < 2000) {
        while (wl_display_prepare_read(capture.display) != 0) {
            if (wl_display_dispatch_pending(capture.display) < 0) return false;
        }
        wl_display_flush(capture.display);
        pollfd fd{wl_display_get_fd(capture.display), POLLIN, 0};
        if (poll(&fd, 1, static_cast<int>(2000 - deadline.elapsed())) <= 0) {
            wl_display_cancel_read(capture.display); return false;
        }
        if (wl_display_read_events(capture.display) < 0 || wl_display_dispatch_pending(capture.display) < 0) return false;
    }
    return (constraints ? capture.constraintsReady : capture.done) && !capture.failed;
}
bool sync(Capture& capture) {
    capture.done = false;
    auto* callback = wl_display_sync(capture.display);
    static const wl_callback_listener listener = {
        [](void* data, wl_callback*, uint32_t) { static_cast<Capture*>(data)->done = true; }
    };
    wl_callback_add_listener(callback, &listener, &capture);
    const bool success = awaitEvents(capture);
    wl_callback_destroy(callback);
    return success;
}
const ext_foreign_toplevel_handle_v1_listener handleListener = {
    .closed = [](void* data, ext_foreign_toplevel_handle_v1* handle) {
        auto& capture = *static_cast<Capture*>(data);
        if (capture.target == handle) capture.failed = true;
    },
    .done = [](void*, ext_foreign_toplevel_handle_v1*) {},
    .title = [](void*, ext_foreign_toplevel_handle_v1*, const char*) {},
    .app_id = [](void*, ext_foreign_toplevel_handle_v1*, const char*) {},
    .identifier = [](void* data, ext_foreign_toplevel_handle_v1* handle, const char* identifier) {
        auto& capture = *static_cast<Capture*>(data);
        if (capture.identifier == QString::fromUtf8(identifier)) capture.target = handle;
    }
};
const ext_foreign_toplevel_list_v1_listener listListener = {
    .toplevel = [](void* data, ext_foreign_toplevel_list_v1*, ext_foreign_toplevel_handle_v1* handle) {
        static_cast<Capture*>(data)->handles.push_back(handle);
        ext_foreign_toplevel_handle_v1_add_listener(handle, &handleListener, data);
    },
    .finished = [](void* data, ext_foreign_toplevel_list_v1*) { static_cast<Capture*>(data)->failed = true; }
};
const wl_registry_listener registryListener = {
    .global = [](void* data, wl_registry* registry, uint32_t name, const char* interface, uint32_t) {
        auto& c = *static_cast<Capture*>(data);
        if (std::strcmp(interface, "wl_shm") == 0)
            c.shm = static_cast<wl_shm*>(wl_registry_bind(registry, name, &wl_shm_interface, 1));
        else if (std::strcmp(interface, "ext_foreign_toplevel_list_v1") == 0) {
            c.list = static_cast<ext_foreign_toplevel_list_v1*>(wl_registry_bind(registry, name, &ext_foreign_toplevel_list_v1_interface, 1));
            ext_foreign_toplevel_list_v1_add_listener(c.list, &listListener, data);
        } else if (std::strcmp(interface, "ext_foreign_toplevel_image_capture_source_manager_v1") == 0)
            c.sources = static_cast<ext_foreign_toplevel_image_capture_source_manager_v1*>(wl_registry_bind(registry, name, &ext_foreign_toplevel_image_capture_source_manager_v1_interface, 1));
        else if (std::strcmp(interface, "ext_image_copy_capture_manager_v1") == 0)
            c.manager = static_cast<ext_image_copy_capture_manager_v1*>(wl_registry_bind(registry, name, &ext_image_copy_capture_manager_v1_interface, 1));
    },
    .global_remove = [](void*, wl_registry*, uint32_t) {}
};
const ext_image_copy_capture_session_v1_listener sessionListener = {
    .buffer_size = [](void* data, ext_image_copy_capture_session_v1*, uint32_t width, uint32_t height) {
        auto& c = *static_cast<Capture*>(data); c.width = width; c.height = height;
    },
    .shm_format = [](void* data, ext_image_copy_capture_session_v1*, uint32_t format) {
        auto& c = *static_cast<Capture*>(data);
        if (format == WL_SHM_FORMAT_ARGB8888 || format == WL_SHM_FORMAT_XRGB8888) { c.format = format; c.haveFormat = true; }
    },
    .dmabuf_device = [](void*, ext_image_copy_capture_session_v1*, wl_array*) {},
    .dmabuf_format = [](void*, ext_image_copy_capture_session_v1*, uint32_t, wl_array*) {},
    .done = [](void* data, ext_image_copy_capture_session_v1*) { static_cast<Capture*>(data)->constraintsReady = true; },
    .stopped = [](void* data, ext_image_copy_capture_session_v1*) { static_cast<Capture*>(data)->failed = true; }
};
const ext_image_copy_capture_frame_v1_listener frameListener = {
    .transform = [](void* data, ext_image_copy_capture_frame_v1*, uint32_t transform) { static_cast<Capture*>(data)->transform = transform; },
    .damage = [](void*, ext_image_copy_capture_frame_v1*, int32_t, int32_t, int32_t, int32_t) {},
    .presentation_time = [](void*, ext_image_copy_capture_frame_v1*, uint32_t, uint32_t, uint32_t) {},
    .ready = [](void* data, ext_image_copy_capture_frame_v1*) { static_cast<Capture*>(data)->done = true; },
    .failed = [](void* data, ext_image_copy_capture_frame_v1*, uint32_t) { static_cast<Capture*>(data)->failed = true; }
};
}
QImage captureNativeWindow(const QString& identifier) {
    Capture c;
    c.identifier = identifier;
    c.display = wl_display_connect(nullptr);
    if (!c.display) return {};
    c.registry = wl_display_get_registry(c.display);
    wl_registry_add_listener(c.registry, &registryListener, &c);
    if (!sync(c) || !sync(c) || !c.shm || !c.sources || !c.manager || !c.target) return {};
    c.source = ext_foreign_toplevel_image_capture_source_manager_v1_create_source(c.sources, c.target);
    c.session = ext_image_copy_capture_manager_v1_create_session(c.manager, c.source, 0);
    ext_image_copy_capture_session_v1_add_listener(c.session, &sessionListener, &c);
    c.done = false;
    if (!awaitEvents(c, true) || !c.haveFormat || !c.width || !c.height || c.width > 16384 || c.height > 16384) return {};
    c.size = static_cast<size_t>(c.width) * c.height * 4;
    if (c.size > 256 * 1024 * 1024) return {};
    const int fd = memfd_create("caelestia-window-preview", MFD_CLOEXEC);
    if (fd < 0) return {};
    if (ftruncate(fd, static_cast<off_t>(c.size)) < 0) { close(fd); return {}; }
    c.memory = mmap(nullptr, c.size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (c.memory == MAP_FAILED) { close(fd); return {}; }
    auto* pool = wl_shm_create_pool(c.shm, fd, static_cast<int32_t>(c.size));
    close(fd);
    c.buffer = wl_shm_pool_create_buffer(pool, 0, static_cast<int32_t>(c.width), static_cast<int32_t>(c.height), static_cast<int32_t>(c.width * 4), c.format);
    wl_shm_pool_destroy(pool);
    c.frame = ext_image_copy_capture_session_v1_create_frame(c.session);
    ext_image_copy_capture_frame_v1_add_listener(c.frame, &frameListener, &c);
    ext_image_copy_capture_frame_v1_attach_buffer(c.frame, c.buffer);
    ext_image_copy_capture_frame_v1_damage_buffer(c.frame, 0, 0, static_cast<int32_t>(c.width), static_cast<int32_t>(c.height));
    ext_image_copy_capture_frame_v1_capture(c.frame);
    c.done = false;
    if (!awaitEvents(c)) return {};
    QImage image(static_cast<const uchar*>(c.memory), static_cast<int>(c.width), static_cast<int>(c.height), static_cast<int>(c.width * 4), c.format == WL_SHM_FORMAT_ARGB8888 ? QImage::Format_ARGB32_Premultiplied : QImage::Format_RGB32);
    QTransform transform;
    if (c.transform >= WL_OUTPUT_TRANSFORM_FLIPPED) transform.scale(-1, 1);
    transform.rotate(-90 * static_cast<int>(c.transform % 4));
    return c.transform ? image.transformed(transform) : image.copy();
}
}
