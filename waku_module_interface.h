#pragma once

#include <QtCore/QObject>
#include "interface.h"

class WakuModuleInterface : public PluginInterface
{
public:
    virtual ~WakuModuleInterface() {}
    Q_INVOKABLE virtual bool foo(const QString &bar) = 0;
    Q_INVOKABLE virtual bool initWaku(const QString &cfg) = 0;
    Q_INVOKABLE virtual bool startWaku() = 0;
    Q_INVOKABLE virtual bool stopWaku() = 0;
    Q_INVOKABLE virtual bool setEventCallback() = 0;
    Q_INVOKABLE virtual bool relaySubscribe(const QString &contentTopic, const QString &pubSubTopic = QString()) = 0;
    Q_INVOKABLE virtual bool relayPublish(const QString &pubSubTopic, const QString &jsonWakuMessage) = 0;
    Q_INVOKABLE virtual bool filterSubscribe(const QString &pubSubTopic, const QString &contentTopics) = 0;
    Q_INVOKABLE virtual bool storeQuery(const QString &jsonQuery, const QString &peerAddr) = 0;
    Q_INVOKABLE virtual bool getConnectedPeers() = 0;
    Q_INVOKABLE virtual bool getMetrics() = 0;
    Q_INVOKABLE virtual bool lightPublish(const QString &pubSubTopic, const QString &jsonWakuMessage) = 0;
    Q_INVOKABLE virtual bool getMixnodePoolSize() = 0;
    Q_INVOKABLE virtual bool getLightpushPeersCount() = 0;

signals:
    // for now this is required for events, later it might not be necessary if using a proxy
    void eventResponse(const QString &eventName, const QVariantList &data);
};

#define WakuModuleInterface_iid "org.logos.WakuModuleInterface"
Q_DECLARE_INTERFACE(WakuModuleInterface, WakuModuleInterface_iid)