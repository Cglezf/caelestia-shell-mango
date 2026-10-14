#include "windowcapture.hpp"
#include "nativecapture.hpp"
#include <qtconcurrentrun.h>

#include <qpainter.h>

namespace caelestia::images {
using Qt::StringLiterals::operator""_s;

WindowCapture::WindowCapture(QQuickItem* parent)
    : QQuickPaintedItem(parent) {
    connect(&m_nativeCapture, &QFutureWatcher<QImage>::finished, this, [this] {
        if (!m_active || m_captureIdentifier != m_identifier) {
            if (m_active) m_refresh.start(0);
            return;
        }
        const auto image = m_nativeCapture.result();
        if (image.isNull()) {
            m_nativeUnavailable = true;
            capture(); // Older compositors retain the grim compatibility path.
        } else {
            const bool hadContent = hasContent();
            m_image = image;
            resizePreview();
            update();
            if (!hadContent) emit hasContentChanged();
            m_refresh.start(100);
        }
    });
    m_refresh.setSingleShot(true);
    m_timeout.setSingleShot(true);
    m_timeout.setInterval(2000);
    connect(&m_refresh, &QTimer::timeout, this, &WindowCapture::capture);
    connect(&m_timeout, &QTimer::timeout, this, [this] { m_process.kill(); });
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_timeout.stop();
        const auto bytes = m_process.readAllStandardOutput();
        m_process.readAllStandardError();
        if (!m_active || m_captureIdentifier != m_identifier)
            return;
        const auto image = code == 0 && status == QProcess::NormalExit
            ? QImage::fromData(bytes, "PPM") : QImage();
        if (!image.isNull()) {
            const bool hadContent = hasContent();
            m_image = image;
            resizePreview();
            update();
            if (!hadContent)
                emit hasContentChanged();
        } else {
            const bool hadContent = hasContent();
            m_image = {};
            resizePreview();
            update();
            if (hadContent)
                emit hasContentChanged();
        }
        // Bound refresh work and retry unavailable windows less frequently.
        m_refresh.start(image.isNull() ? 2000 : 200);
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            m_timeout.stop();
            // No supported grim executable: retain the normal QML fallback.
        }
    });
}

WindowCapture::~WindowCapture() {
    m_process.kill();
    m_process.waitForFinished(1000);
}

void WindowCapture::setIdentifier(const QString& identifier) {
    if (m_identifier == identifier)
        return;
    m_identifier = identifier;
    reset();
    emit identifierChanged();
    if (m_active && !m_identifier.isEmpty())
        m_refresh.start(0);
}

void WindowCapture::setActive(bool active) {
    if (m_active == active)
        return;
    m_active = active;
    reset();
    emit activeChanged();
    if (m_active && !m_identifier.isEmpty())
        m_refresh.start(0);
}

void WindowCapture::setConstraintSize(const QSizeF& size) {
    if (m_constraintSize == size)
        return;
    m_constraintSize = size;
    resizePreview();
    emit constraintSizeChanged();
}

void WindowCapture::reset() {
    m_refresh.stop();
    m_timeout.stop();
    m_nativeUnavailable = false;
    if (!m_nativeCapture.isRunning()) m_captureIdentifier.clear();
    if (m_process.state() != QProcess::NotRunning)
        m_process.kill();
    const bool hadContent = hasContent();
    m_image = {};
    resizePreview();
    update();
    if (hadContent)
        emit hasContentChanged();
}

void WindowCapture::capture() {
    if (!m_active || m_identifier.isEmpty())
        return;
    if (m_process.state() != QProcess::NotRunning) {
        m_refresh.start(50);
        return;
    }
    if (m_nativeCapture.isRunning()) return;
    m_captureIdentifier = m_identifier;
    if (!m_nativeUnavailable) {
        const auto identifier = m_identifier;
        m_nativeCapture.setFuture(QtConcurrent::run([identifier] { return captureNativeWindow(identifier); }));
        return;
    }
    // Pass an exact protocol identifier as an argument, never a shell command.
    m_process.start(u"grim"_s, {u"-T"_s, m_identifier, u"-t"_s, u"ppm"_s, u"-"_s});
    m_timeout.start();
}

void WindowCapture::resizePreview() {
    QSizeF size = m_image.size();
    if (!size.isEmpty()) {
        const QSizeF bounds(m_constraintSize.width() > 0 ? m_constraintSize.width() : size.width(),
                            m_constraintSize.height() > 0 ? m_constraintSize.height() : size.height());
        size.scale(bounds, Qt::KeepAspectRatio);
    }
    setImplicitSize(size.width(), size.height());
}

void WindowCapture::paint(QPainter* painter) {
    if (!m_image.isNull()) {
        painter->setRenderHint(QPainter::SmoothPixmapTransform);
        painter->drawImage(boundingRect(), m_image);
    }
}
} // namespace caelestia::images
