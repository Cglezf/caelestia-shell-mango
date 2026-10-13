#pragma once

#include <qimage.h>
#include <qprocess.h>
#include <qqmlintegration.h>
#include <qquickpainteditem.h>
#include <qtimer.h>

namespace caelestia::images {

class WindowCapture : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString identifier READ identifier WRITE setIdentifier NOTIFY identifierChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool hasContent READ hasContent NOTIFY hasContentChanged)
    Q_PROPERTY(QSizeF constraintSize READ constraintSize WRITE setConstraintSize NOTIFY constraintSizeChanged)

public:
    explicit WindowCapture(QQuickItem* parent = nullptr);
    ~WindowCapture() override;
    void paint(QPainter* painter) override;
    QString identifier() const { return m_identifier; }
    bool active() const { return m_active; }
    bool hasContent() const { return !m_image.isNull(); }
    QSizeF constraintSize() const { return m_constraintSize; }
    void setIdentifier(const QString& identifier);
    void setActive(bool active);
    void setConstraintSize(const QSizeF& size);

signals:
    void identifierChanged();
    void activeChanged();
    void hasContentChanged();
    void constraintSizeChanged();

private:
    void capture();
    void reset();
    void resizePreview();
    QString m_identifier;
    QString m_captureIdentifier;
    bool m_active = false;
    QSizeF m_constraintSize;
    QImage m_image;
    QProcess m_process;
    QTimer m_refresh;
    QTimer m_timeout;
};

} // namespace caelestia::images
