#pragma once
#include <qobject.h>
#include <qqmlintegration.h>

namespace caelestia::services {
class OutputPower : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    using QObject::QObject;
    Q_INVOKABLE void setEnabled(bool enabled);
signals:
    void failed(const QString& message);
};
}
